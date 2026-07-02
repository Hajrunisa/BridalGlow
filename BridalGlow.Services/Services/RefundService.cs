using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Stripe;
using StripeRefundService = Stripe.RefundService;
using RefundEntity = BridalGlow.Data.Entities.Refund;

namespace BridalGlow.Services.Services;

public class RefundService : IRefundService
{
    private const int MaxPageSize = 100;

    private static readonly RefundStatus[] ActiveRefundStatuses =
    [
        RefundStatus.Requested,
        RefundStatus.Approved,
        RefundStatus.Processing
    ];

    private readonly BridalGlowDbContext _context;
    private readonly IDomainNotificationPublisher _domainNotifications;
    private readonly IFinancialLedgerService _ledger;

    public RefundService(
        BridalGlowDbContext context,
        IConfiguration configuration,
        IDomainNotificationPublisher domainNotifications,
        IFinancialLedgerService ledger)
    {
        _context = context;
        _domainNotifications = domainNotifications;
        _ledger = ledger;
        StripeConfiguration.ApiKey = StripeSecretResolver.ResolveSecretKey(configuration);
    }

    public async Task<RefundResponse> RequestAsync(
        int userId, bool isStaff, RefundRequestCreateRequest request)
    {
        var payment = await _context.Payments
            .Include(p => p.RentalReservation)
            .FirstOrDefaultAsync(p => p.Id == request.PaymentId && !p.IsDeleted);

        if (payment == null)
            throw new UserException("Uplata nije pronađena.");

        if (payment.Status != PaymentStatus.Succeeded)
            throw new UserException("Refund je moguć samo za uspješno plaćene uplate.");

        if (!isStaff && payment.CustomerUserId != userId)
            throw new UserException("Nemate dozvolu za refund ove uplate.");

        if (string.IsNullOrWhiteSpace(payment.ProviderChargeId))
            throw new UserException("Uplata nema povezan Stripe charge — refund nije moguć.");

        var hasActiveRefund = await _context.Refunds
            .AnyAsync(r => r.PaymentId == payment.Id
                        && !r.IsDeleted
                        && ActiveRefundStatuses.Contains(r.Status));

        if (hasActiveRefund)
            throw new UserException("Za ovu uplatu već postoji aktivan refund zahtjev.");

        var refundableAmount = await GetRefundableAmountAsync(payment);
        if (refundableAmount <= 0m)
            throw new UserException("Za ovu uplatu nema preostalog iznosa za refund.");

        var amount = request.Amount ?? refundableAmount;
        if (amount <= 0m)
            throw new UserException("Iznos refunda mora biti veći od nule.");

        if (amount > refundableAmount)
            throw new UserException(
                $"Traženi iznos ({amount:F2} {payment.Currency}) premašuje dostupan iznos za refund ({refundableAmount:F2} {payment.Currency}).");

        var now = DateTime.UtcNow;
        var refund = new RefundEntity
        {
            PaymentId = payment.Id,
            RequestedByUserId = userId,
            Status = RefundStatus.Requested,
            ReasonCode = request.ReasonCode,
            ReasonText = request.ReasonText?.Trim(),
            Amount = amount,
            Currency = payment.Currency,
            RequestedAtUtc = now,
            CreatedAtUtc = now,
            IsDeleted = false
        };

        _context.Refunds.Add(refund);
        await _context.SaveChangesAsync();

        var reservationLabel = payment.RentalReservation?.ReservationNumber
            ?? payment.RentalReservationId?.ToString()
            ?? "N/A";

        await _domainNotifications.StageStaffOperationalNotificationsAsync(
            "Nov zahtjev za refund",
            $"Nov zahtjev za refund u iznosu od {amount:F2} {payment.Currency} za rezervaciju {reservationLabel}.",
            NotificationType.RefundProcessed,
            relatedEntityType: "Refund",
            relatedEntityId: refund.Id);

        await _context.SaveChangesAsync();

        return MapToResponse(refund);
    }

    public async Task<RefundResponse> ApproveAsync(int id, int staffUserId)
    {
        var refund = await GetRefundOrThrowAsync(id);

        if (refund.Status != RefundStatus.Requested)
            throw new UserException(
                $"Samo refund zahtjevi sa statusom 'Requested' mogu biti odobreni. Trenutni status: {refund.Status}.");

        var now = DateTime.UtcNow;
        refund.Status = RefundStatus.Approved;
        refund.ApprovedByUserId = staffUserId;
        refund.ApprovedAtUtc = now;
        refund.UpdatedAtUtc = now;

        await _context.SaveChangesAsync();
        return MapToResponse(refund);
    }

    public async Task<RefundResponse> RejectAsync(
        int id, int staffUserId, RefundRejectRequest request)
    {
        var refund = await GetRefundOrThrowAsync(id);

        if (refund.Status != RefundStatus.Requested)
            throw new UserException(
                $"Samo refund zahtjevi sa statusom 'Requested' mogu biti odbijeni. Trenutni status: {refund.Status}.");

        var now = DateTime.UtcNow;
        refund.Status = RefundStatus.Rejected;
        refund.ApprovedByUserId = staffUserId;
        refund.RejectedAtUtc = now;
        refund.FailureReason = request.Reason?.Trim();
        refund.UpdatedAtUtc = now;

        await _context.SaveChangesAsync();
        return MapToResponse(refund);
    }

    public async Task<RefundResponse> ProcessAsync(int id, int staffUserId)
    {
        var refund = await GetRefundOrThrowAsync(id);

        if (refund.Status != RefundStatus.Approved)
            throw new UserException(
                $"Refund se može obraditi samo iz statusa 'Approved'. Trenutni status: {refund.Status}.");

        var payment = refund.Payment;
        if (string.IsNullOrWhiteSpace(payment.ProviderChargeId))
            throw new UserException("Uplata nema povezan Stripe charge — refund nije moguć.");

        var refundableAmount = await GetRefundableAmountAsync(payment);
        if (refund.Amount > refundableAmount)
            throw new UserException(
                $"Iznos refunda ({refund.Amount:F2}) premašuje dostupan iznos ({refundableAmount:F2}).");

        var now = DateTime.UtcNow;
        refund.Status = RefundStatus.Processing;
        refund.UpdatedAtUtc = now;
        await _context.SaveChangesAsync();

        var amountInCents = (long)Math.Round(refund.Amount * 100m, MidpointRounding.AwayFromZero);

        try
        {
            var stripeRefundService = new StripeRefundService();
            var stripeRefund = await stripeRefundService.CreateAsync(new RefundCreateOptions
            {
                Charge = payment.ProviderChargeId,
                Amount = amountInCents,
                Metadata = new Dictionary<string, string>
                {
                    { "refundId", refund.Id.ToString() },
                    { "paymentId", payment.Id.ToString() }
                }
            });

            refund.ProviderRefundId = stripeRefund.Id;
            refund.UpdatedAtUtc = DateTime.UtcNow;

            if (stripeRefund.Status == "succeeded")
                await ApplyRefundSucceededAsync(refund, payment, stripeRefund.Id, now);
            else if (stripeRefund.Status is "failed" or "canceled")
                await ApplyRefundFailedAsync(refund, stripeRefund.FailureReason ?? "Stripe refund nije uspio.");

            await _context.SaveChangesAsync();
        }
        catch (StripeException ex)
        {
            refund.Status = RefundStatus.Failed;
            refund.FailureReason = ex.StripeError?.Message ?? ex.Message;
            refund.UpdatedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            throw new UserException($"Stripe refund nije uspio: {refund.FailureReason}");
        }

        return MapToResponse(refund);
    }

    public async Task<PagedResult<RefundResponse>> GetAsync(RefundSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery();
        query = ApplyFilter(query, search);

        return await ExecutePagedQueryAsync(query, search);
    }

    public async Task<PagedResult<RefundResponse>> GetMineAsync(
        int customerUserId, RefundSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery()
            .Where(r => r.Payment.CustomerUserId == customerUserId);
        query = ApplyFilter(query, search);

        return await ExecutePagedQueryAsync(query, search);
    }

    public async Task ApplyChargeRefundedAsync(Charge charge)
    {
        var payment = await _context.Payments
            .Include(p => p.RentalReservation)
            .FirstOrDefaultAsync(p => p.ProviderChargeId == charge.Id && !p.IsDeleted);

        if (payment == null)
            return;

        var stripeRefundService = new StripeRefundService();
        var stripeRefunds = await stripeRefundService.ListAsync(new RefundListOptions
        {
            Charge = charge.Id,
            Limit = 100
        });

        foreach (var stripeRefund in stripeRefunds.Data)
        {
            if (stripeRefund.Status == "succeeded")
                await TryApplyStripeRefundSucceededAsync(stripeRefund, payment);
        }

        await _context.SaveChangesAsync();
    }

    public async Task ApplyRefundUpdatedAsync(Stripe.Refund stripeRefund)
    {
        var refund = await ResolveLocalRefundAsync(stripeRefund);
        if (refund == null)
            return;

        var payment = refund.Payment
            ?? await _context.Payments
                .Include(p => p.RentalReservation)
                .FirstOrDefaultAsync(p => p.Id == refund.PaymentId && !p.IsDeleted);

        if (payment == null)
            return;

        if (!string.IsNullOrWhiteSpace(stripeRefund.Id))
            refund.ProviderRefundId = stripeRefund.Id;

        switch (stripeRefund.Status)
        {
            case "succeeded":
                await ApplyRefundSucceededAsync(
                    refund,
                    payment,
                    stripeRefund.Id,
                    DateTime.UtcNow);
                break;
            case "failed":
            case "canceled":
                if (refund.Status is RefundStatus.Processing or RefundStatus.Approved)
                    await ApplyRefundFailedAsync(
                        refund,
                        stripeRefund.FailureReason ?? "Stripe refund nije uspio.");
                break;
        }

        await _context.SaveChangesAsync();
    }

    private async Task TryApplyStripeRefundSucceededAsync(
        Stripe.Refund stripeRefund, Payment payment)
    {
        var refund = await ResolveLocalRefundAsync(stripeRefund);
        if (refund == null)
            return;

        await ApplyRefundSucceededAsync(
            refund,
            payment,
            stripeRefund.Id,
            DateTime.UtcNow);
    }

    private async Task ApplyRefundSucceededAsync(
        RefundEntity refund, Payment payment, string providerRefundId, DateTime now)
    {
        if (refund.Status == RefundStatus.Succeeded)
            return;

        refund.Status = RefundStatus.Succeeded;
        refund.ProviderRefundId = providerRefundId;
        refund.ProcessedAtUtc ??= now;
        refund.UpdatedAtUtc = now;
        refund.FailureReason = null;

        string? reservationNumber = null;

        if (payment.RentalReservationId.HasValue)
        {
            var reservation = payment.RentalReservation
                ?? await _context.RentalReservations
                    .FirstOrDefaultAsync(r => r.Id == payment.RentalReservationId.Value && !r.IsDeleted);

            if (reservation != null)
            {
                reservationNumber = reservation.ReservationNumber;

                var previouslyRefunded = await GetTotalRefundedAmountAsync(payment.Id);
                var totalRefunded = previouslyRefunded + refund.Amount;
                var capturedAmount = payment.CapturedAmount > 0m ? payment.CapturedAmount : payment.Amount;

                if (totalRefunded >= capturedAmount
                    && reservation.Status != RentalReservationStatus.Refunded)
                {
                    var previousStatus = reservation.Status;
                    reservation.Status = RentalReservationStatus.Refunded;
                    reservation.UpdatedAtUtc = now;

                    _context.RentalReservationStatusHistories.Add(new RentalReservationStatusHistory
                    {
                        RentalReservationId = reservation.Id,
                        ChangedByUserId = refund.ApprovedByUserId ?? refund.RequestedByUserId,
                        FromStatus = previousStatus,
                        ToStatus = RentalReservationStatus.Refunded,
                        ChangedAtUtc = now,
                        Reason = "Refund uspješno obrađen"
                    });
                }
            }
        }

        await _ledger.RecordRefundAsync(refund, payment, reservationNumber);

        var reservationLabel = reservationNumber ?? payment.RentalReservationId?.ToString() ?? "N/A";

        _domainNotifications.StageCustomerNotification(
            payment.CustomerUserId,
            "Refund obrađen",
            $"Vaš refund u iznosu od {refund.Amount:F2} {refund.Currency} za rezervaciju {reservationLabel} je uspješno obrađen.",
            NotificationType.RefundProcessed,
            relatedEntityType: "Refund",
            relatedEntityId: refund.Id);

        await _domainNotifications.StageStaffOperationalNotificationsAsync(
            "Refund obrađen",
            $"Refund u iznosu od {refund.Amount:F2} {refund.Currency} za rezervaciju {reservationLabel} je uspješno obrađen.",
            NotificationType.RefundProcessed,
            relatedEntityType: "Refund",
            relatedEntityId: refund.Id);
    }

    private Task ApplyRefundFailedAsync(RefundEntity refund, string reason)
    {
        if (refund.Status == RefundStatus.Succeeded)
            return Task.CompletedTask;

        refund.Status = RefundStatus.Failed;
        refund.FailureReason = reason;
        refund.UpdatedAtUtc = DateTime.UtcNow;
        return Task.CompletedTask;
    }

    private async Task<RefundEntity?> ResolveLocalRefundAsync(Stripe.Refund stripeRefund)
    {
        if (stripeRefund.Metadata.TryGetValue("refundId", out var refundIdValue)
            && int.TryParse(refundIdValue, out var refundId))
        {
            var refundById = await BuildBaseQuery()
                .FirstOrDefaultAsync(r => r.Id == refundId && !r.IsDeleted);

            if (refundById != null)
                return refundById;
        }

        if (!string.IsNullOrWhiteSpace(stripeRefund.Id))
        {
            var refundByProviderId = await BuildBaseQuery()
                .FirstOrDefaultAsync(r => r.ProviderRefundId == stripeRefund.Id && !r.IsDeleted);

            if (refundByProviderId != null)
                return refundByProviderId;
        }

        return null;
    }

    private async Task<RefundEntity> GetRefundOrThrowAsync(int id)
    {
        var refund = await BuildBaseQuery()
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (refund == null)
            throw new UserException("Refund zahtjev nije pronađen.");

        return refund;
    }

    private async Task<decimal> GetRefundableAmountAsync(Payment payment)
    {
        var capturedAmount = payment.CapturedAmount > 0m ? payment.CapturedAmount : payment.Amount;
        var totalRefunded = await GetTotalRefundedAmountAsync(payment.Id);
        return capturedAmount - totalRefunded;
    }

    private async Task<decimal> GetTotalRefundedAmountAsync(int paymentId)
    {
        return await _context.Refunds
            .Where(r => r.PaymentId == paymentId
                     && !r.IsDeleted
                     && r.Status == RefundStatus.Succeeded)
            .SumAsync(r => r.Amount);
    }

    private IQueryable<RefundEntity> BuildBaseQuery()
    {
        return _context.Refunds
            .Include(r => r.Payment)
            .Where(r => !r.IsDeleted);
    }

    private static IQueryable<RefundEntity> ApplyFilter(IQueryable<RefundEntity> query, RefundSearchObject search)
    {
        if (search.PaymentId.HasValue)
            query = query.Where(r => r.PaymentId == search.PaymentId.Value);

        if (search.RequestedByUserId.HasValue)
            query = query.Where(r => r.RequestedByUserId == search.RequestedByUserId.Value);

        if (search.Status.HasValue)
            query = query.Where(r => r.Status == search.Status.Value);

        if (search.FromDate.HasValue)
            query = query.Where(r => r.RequestedAtUtc >= search.FromDate.Value);

        if (search.ToDate.HasValue)
            query = query.Where(r => r.RequestedAtUtc <= search.ToDate.Value);

        return query;
    }

    private async Task<PagedResult<RefundResponse>> ExecutePagedQueryAsync(
        IQueryable<RefundEntity> query, RefundSearchObject search)
    {
        query = query.OrderByDescending(r => r.RequestedAtUtc);

        int? totalCount = null;
        if (search.IncludeTotalCount)
            totalCount = await query.CountAsync();

        if (!search.RetrieveAll)
        {
            if (search.Page.HasValue && search.PageSize.HasValue)
                query = query.Skip(search.Page.Value * search.PageSize.Value);
            if (search.PageSize.HasValue)
                query = query.Take(search.PageSize.Value);
        }

        var list = await query.ToListAsync();
        return new PagedResult<RefundResponse>
        {
            Items = list.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    private static void NormalizePagination(RefundSearchObject search)
    {
        if (!search.PageSize.HasValue || search.PageSize.Value <= 0)
            search.PageSize = 30;
        if (search.PageSize.Value > MaxPageSize)
            search.PageSize = MaxPageSize;
        if (!search.Page.HasValue || search.Page.Value < 0)
            search.Page = 0;
    }

    private static RefundResponse MapToResponse(RefundEntity entity)
    {
        return new RefundResponse
        {
            Id = entity.Id,
            PaymentId = entity.PaymentId,
            RequestedByUserId = entity.RequestedByUserId,
            ApprovedByUserId = entity.ApprovedByUserId,
            Status = entity.Status,
            StatusLabel = entity.Status.ToString(),
            ReasonCode = entity.ReasonCode,
            ReasonCodeLabel = entity.ReasonCode.ToString(),
            ReasonText = entity.ReasonText,
            Amount = entity.Amount,
            Currency = entity.Currency,
            ProviderRefundId = entity.ProviderRefundId,
            RequestedAtUtc = entity.RequestedAtUtc,
            ApprovedAtUtc = entity.ApprovedAtUtc,
            ProcessedAtUtc = entity.ProcessedAtUtc,
            RejectedAtUtc = entity.RejectedAtUtc,
            FailureReason = entity.FailureReason,
            CreatedAtUtc = entity.CreatedAtUtc,
            UpdatedAtUtc = entity.UpdatedAtUtc
        };
    }
}
