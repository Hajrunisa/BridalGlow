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

namespace BridalGlow.Services.Services;

public class PaymentService : IPaymentService
{
    private const int MaxPageSize = 100;
    private readonly BridalGlowDbContext _context;
    private readonly IDomainNotificationPublisher _domainNotifications;
    private readonly IFinancialLedgerService _ledger;
    private readonly string _stripeSecretKey;

    public PaymentService(
        BridalGlowDbContext context,
        IConfiguration configuration,
        IDomainNotificationPublisher domainNotifications,
        IFinancialLedgerService ledger)
    {
        _context = context;
        _domainNotifications = domainNotifications;
        _ledger = ledger;
        _stripeSecretKey = StripeSecretResolver.ResolveSecretKey(configuration);
        StripeConfiguration.ApiKey = _stripeSecretKey;
    }

    public async Task<PaymentIntentResponse> CreatePaymentIntentAsync(
        int customerUserId, CreatePaymentIntentRequest request)
    {
        var reservation = await _context.RentalReservations
            .Include(r => r.Customer)
            .Include(r => r.Dress)
            .FirstOrDefaultAsync(r => r.Id == request.RentalReservationId && !r.IsDeleted);

        if (reservation == null)
            throw new UserException("Rezervacija nije pronađena.");

        if (reservation.Status != RentalReservationStatus.Approved)
            throw new UserException(
                $"Plaćanje je moguće samo za odobrene rezervacije. Trenutni status: {reservation.Status}.");

        if (reservation.CustomerUserId != customerUserId)
            throw new UserException("Nemate dozvolu za plaćanje ove rezervacije.");

        var hasSuccessfulPayment = await _context.Payments
            .AnyAsync(p => p.RentalReservationId == reservation.Id
                        && !p.IsDeleted
                        && p.Status == PaymentStatus.Succeeded);

        if (hasSuccessfulPayment)
            throw new UserException("Za ovu rezervaciju već postoji uspješna uplata.");

        if (reservation.TotalAmount <= 0m)
            throw new UserException("Iznos rezervacije mora biti veći od nule.");

        var customer = reservation.Customer;
        if (customer == null || customer.IsDeleted)
            throw new UserException("Korisnik rezervacije nije pronađen.");

        var customerName = $"{customer.FirstName} {customer.LastName}".Trim();
        if (string.IsNullOrWhiteSpace(customerName))
            customerName = customer.Username;

        var stripeCustomerService = new CustomerService();
        var stripeCustomer = await stripeCustomerService.CreateAsync(new CustomerCreateOptions
        {
            Name = customerName,
            Email = customer.Email,
            Metadata = new Dictionary<string, string>
            {
                { "customer_user_id", customerUserId.ToString() },
                { "rental_reservation_id", reservation.Id.ToString() }
            }
        });

        var ephemeralKeyService = new EphemeralKeyService();
        var ephemeralKey = await ephemeralKeyService.CreateAsync(new EphemeralKeyCreateOptions
        {
            Customer = stripeCustomer.Id
        });

        var amountInCents = (long)Math.Round(reservation.TotalAmount * 100m, MidpointRounding.AwayFromZero);
        var currency = reservation.Currency.ToLowerInvariant();

        var paymentIntentService = new PaymentIntentService();
        var paymentIntent = await paymentIntentService.CreateAsync(new PaymentIntentCreateOptions
        {
            Amount = amountInCents,
            Currency = currency,
            Customer = stripeCustomer.Id,
            AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions
            {
                Enabled = true
            },
            Description = $"BridalGlow rental payment — {reservation.ReservationNumber}",
            Metadata = new Dictionary<string, string>
            {
                { "rental_reservation_id", reservation.Id.ToString() },
                { "reservation_number", reservation.ReservationNumber },
                { "customer_user_id", customerUserId.ToString() }
            }
        });

        var now = DateTime.UtcNow;
        var previousStatus = reservation.Status;

        var payment = new Payment
        {
            RentalReservationId = reservation.Id,
            CustomerUserId = customerUserId,
            PaymentType = PaymentType.RentalFull,
            Status = PaymentStatus.Created,
            Provider = PaymentProvider.Stripe,
            ProviderPaymentIntentId = paymentIntent.Id,
            Amount = reservation.TotalAmount,
            Currency = reservation.Currency,
            CapturedAmount = 0m,
            CreatedAtUtc = now,
            IsDeleted = false
        };
        _context.Payments.Add(payment);

        reservation.Status = RentalReservationStatus.AwaitingPayment;
        reservation.UpdatedAtUtc = now;

        _context.RentalReservationStatusHistories.Add(new RentalReservationStatusHistory
        {
            RentalReservationId = reservation.Id,
            ChangedByUserId = customerUserId,
            FromStatus = previousStatus,
            ToStatus = RentalReservationStatus.AwaitingPayment,
            ChangedAtUtc = now,
            Reason = "Payment Intent kreiran — čeka se uplata"
        });

        await _context.SaveChangesAsync();

        await paymentIntentService.UpdateAsync(paymentIntent.Id, new PaymentIntentUpdateOptions
        {
            Metadata = new Dictionary<string, string>
            {
                { "paymentId", payment.Id.ToString() },
                { "rentalReservationId", reservation.Id.ToString() },
                { "reservation_number", reservation.ReservationNumber },
                { "customer_user_id", customerUserId.ToString() }
            }
        });

        return new PaymentIntentResponse
        {
            PaymentId = payment.Id,
            ClientSecret = paymentIntent.ClientSecret,
            EphemeralKey = ephemeralKey.Secret,
            CustomerId = stripeCustomer.Id
        };
    }

    public async Task<PaymentResponse?> GetByIdAsync(
        int id, int? requestingUserId = null, bool isStaff = false)
    {
        var payment = await BuildBaseQuery()
            .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

        if (payment == null)
            return null;

        if (!isStaff && requestingUserId.HasValue && payment.CustomerUserId != requestingUserId.Value)
            throw new UserException("Nemate dozvolu za pregled ove uplate.");

        return MapToResponse(payment);
    }

    public async Task<PaymentStatusResponse> GetStatusAsync(
        int id, int? requestingUserId = null, bool isStaff = false)
    {
        var payment = await GetPaymentForStatusSyncOrThrowAsync(id, requestingUserId, isStaff);
        var paymentIntent = await FetchStripePaymentIntentAsync(payment);
        return BuildStatusResponse(payment, paymentIntent, syncApplied: false);
    }

    public async Task<PaymentStatusResponse> SyncStatusAsync(
        int id, int? requestingUserId = null, bool isStaff = false)
    {
        var payment = await GetPaymentForStatusSyncOrThrowAsync(id, requestingUserId, isStaff);
        var paymentIntent = await FetchStripePaymentIntentAsync(payment);

        var previousStatus = payment.Status;
        var syncApplied = await ApplyStripeStatusAsync(payment, paymentIntent, previousStatus);

        if (syncApplied)
            await _context.SaveChangesAsync();

        return BuildStatusResponse(payment, paymentIntent, syncApplied);
    }

    public async Task<PagedResult<PaymentResponse>> GetMineAsync(
        int customerUserId, PaymentSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery().Where(p => p.CustomerUserId == customerUserId);
        query = ApplyFilter(query, search);

        return await ExecutePagedQueryAsync(query, search);
    }

    public async Task<PagedResult<PaymentResponse>> GetAsync(PaymentSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery();
        query = ApplyFilter(query, search);

        return await ExecutePagedQueryAsync(query, search);
    }

    public async Task ApplyPaymentIntentSucceededAsync(PaymentIntent paymentIntent)
    {
        var payment = await ResolvePaymentFromIntentAsync(paymentIntent);
        if (payment == null || IsTerminalPaymentStatus(payment.Status))
            return;

        await ApplySucceededPaymentAsync(payment, paymentIntent, DateTime.UtcNow);
        await _context.SaveChangesAsync();
    }

    public async Task ApplyPaymentIntentFailedAsync(PaymentIntent paymentIntent)
    {
        var payment = await ResolvePaymentFromIntentAsync(paymentIntent);
        if (payment == null || IsTerminalPaymentStatus(payment.Status))
            return;

        await ApplyFailedPaymentAsync(payment, paymentIntent, DateTime.UtcNow);
        await _context.SaveChangesAsync();
    }

    private IQueryable<Payment> BuildBaseQuery()
    {
        return _context.Payments
            .Include(p => p.Customer)
            .Include(p => p.RentalReservation)
                .ThenInclude(r => r!.Dress)
            .Where(p => !p.IsDeleted);
    }

    private static IQueryable<Payment> ApplyFilter(IQueryable<Payment> query, PaymentSearchObject search)
    {
        if (search.CustomerUserId.HasValue)
            query = query.Where(p => p.CustomerUserId == search.CustomerUserId.Value);

        if (search.RentalReservationId.HasValue)
            query = query.Where(p => p.RentalReservationId == search.RentalReservationId.Value);

        if (search.Status.HasValue)
            query = query.Where(p => p.Status == search.Status.Value);

        if (search.FromDate.HasValue)
            query = query.Where(p => p.CreatedAtUtc >= search.FromDate.Value);

        if (search.ToDate.HasValue)
            query = query.Where(p => p.CreatedAtUtc <= search.ToDate.Value);

        if (search.MinAmount.HasValue)
            query = query.Where(p => p.Amount >= search.MinAmount.Value);

        if (search.MaxAmount.HasValue)
            query = query.Where(p => p.Amount <= search.MaxAmount.Value);

        if (!string.IsNullOrWhiteSpace(search.FTS))
        {
            var fts = search.FTS.Trim().ToLower();
            query = query.Where(p =>
                (p.ProviderPaymentIntentId != null && p.ProviderPaymentIntentId.ToLower().Contains(fts)) ||
                (p.RentalReservation != null && p.RentalReservation.ReservationNumber.ToLower().Contains(fts)) ||
                (p.Customer != null && (
                    p.Customer.Email.ToLower().Contains(fts) ||
                    (p.Customer.FirstName + " " + p.Customer.LastName).ToLower().Contains(fts))));
        }

        return query;
    }

    private async Task<PagedResult<PaymentResponse>> ExecutePagedQueryAsync(
        IQueryable<Payment> query, PaymentSearchObject search)
    {
        query = query.OrderByDescending(p => p.CreatedAtUtc);

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
        return new PagedResult<PaymentResponse>
        {
            Items = list.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    private static void NormalizePagination(PaymentSearchObject search)
    {
        if (!search.PageSize.HasValue || search.PageSize.Value <= 0)
            search.PageSize = 30;
        if (search.PageSize.Value > MaxPageSize)
            search.PageSize = MaxPageSize;
        if (!search.Page.HasValue || search.Page.Value < 0)
            search.Page = 0;
    }

    private static PaymentResponse MapToResponse(Payment entity)
    {
        return new PaymentResponse
        {
            Id = entity.Id,
            RentalReservationId = entity.RentalReservationId,
            TryOnReservationId = entity.TryOnReservationId,
            CustomerUserId = entity.CustomerUserId,
            CustomerName = entity.Customer != null
                ? $"{entity.Customer.FirstName} {entity.Customer.LastName}".Trim()
                : string.Empty,
            CustomerEmail = entity.Customer?.Email ?? string.Empty,
            PaymentType = entity.PaymentType,
            PaymentTypeLabel = entity.PaymentType.ToString(),
            Status = entity.Status,
            StatusLabel = entity.Status.ToString(),
            Provider = entity.Provider,
            ProviderLabel = entity.Provider.ToString(),
            ProviderPaymentIntentId = entity.ProviderPaymentIntentId,
            ProviderChargeId = entity.ProviderChargeId,
            Amount = entity.Amount,
            Currency = entity.Currency,
            CapturedAmount = entity.CapturedAmount,
            FailedReason = entity.FailedReason,
            PaidAtUtc = entity.PaidAtUtc,
            ExpiresAtUtc = entity.ExpiresAtUtc,
            ReservationNumber = entity.RentalReservation?.ReservationNumber,
            DressName = entity.RentalReservation?.Dress?.Name,
            CreatedAtUtc = entity.CreatedAtUtc,
            UpdatedAtUtc = entity.UpdatedAtUtc
        };
    }

    private async Task<Payment> GetPaymentForStatusSyncOrThrowAsync(
        int id, int? requestingUserId, bool isStaff)
    {
        var payment = await BuildBaseQuery()
            .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

        if (payment == null)
            throw new UserException("Uplata nije pronađena.");

        if (!isStaff && requestingUserId.HasValue && payment.CustomerUserId != requestingUserId.Value)
            throw new UserException("Nemate dozvolu za pregled ove uplate.");

        if (string.IsNullOrWhiteSpace(payment.ProviderPaymentIntentId))
            throw new UserException("Uplata nema povezan Stripe PaymentIntent.");

        return payment;
    }

    private async Task<PaymentIntent> FetchStripePaymentIntentAsync(Payment payment)
    {
        var paymentIntentService = new PaymentIntentService();
        return await paymentIntentService.GetAsync(payment.ProviderPaymentIntentId!);
    }

    private async Task<Payment?> ResolvePaymentFromIntentAsync(PaymentIntent paymentIntent)
    {
        if (paymentIntent.Metadata.TryGetValue("paymentId", out var paymentIdValue)
            && int.TryParse(paymentIdValue, out var paymentId))
        {
            var paymentById = await BuildBaseQuery()
                .FirstOrDefaultAsync(p => p.Id == paymentId && !p.IsDeleted);

            if (paymentById != null)
                return paymentById;
        }

        return await BuildBaseQuery()
            .FirstOrDefaultAsync(p => p.ProviderPaymentIntentId == paymentIntent.Id && !p.IsDeleted);
    }

    private async Task<bool> ApplyStripeStatusAsync(
        Payment payment, PaymentIntent paymentIntent, PaymentStatus previousStatus)
    {
        var mappedStatus = MapStripeStatus(paymentIntent);
        if (mappedStatus == previousStatus)
            return false;

        if (IsTerminalPaymentStatus(previousStatus))
            return false;

        var now = DateTime.UtcNow;
        payment.UpdatedAtUtc = now;

        switch (mappedStatus)
        {
            case PaymentStatus.Succeeded:
                await ApplySucceededPaymentAsync(payment, paymentIntent, now);
                break;
            case PaymentStatus.Failed:
                await ApplyFailedPaymentAsync(payment, paymentIntent, now);
                break;
            default:
                payment.Status = mappedStatus;
                break;
        }

        return true;
    }

    private async Task ApplySucceededPaymentAsync(Payment payment, PaymentIntent paymentIntent, DateTime now)
    {
        payment.Status = PaymentStatus.Succeeded;
        payment.PaidAtUtc = now;
        payment.CapturedAmount = paymentIntent.AmountReceived / 100m;
        payment.ProviderChargeId = paymentIntent.LatestChargeId;
        payment.FailedReason = null;

        string? reservationNumber = null;

        if (payment.RentalReservationId.HasValue)
        {
            var reservation = payment.RentalReservation
                ?? await _context.RentalReservations
                    .FirstOrDefaultAsync(r => r.Id == payment.RentalReservationId.Value && !r.IsDeleted);

            if (reservation != null)
            {
                reservationNumber = reservation.ReservationNumber;

                if (reservation.Status == RentalReservationStatus.AwaitingPayment)
                {
                    var previousReservationStatus = reservation.Status;
                    reservation.Status = RentalReservationStatus.Paid;
                    reservation.UpdatedAtUtc = now;

                    _context.RentalReservationStatusHistories.Add(new RentalReservationStatusHistory
                    {
                        RentalReservationId = reservation.Id,
                        ChangedByUserId = payment.CustomerUserId,
                        FromStatus = previousReservationStatus,
                        ToStatus = RentalReservationStatus.Paid,
                        ChangedAtUtc = now,
                        Reason = "Uplata uspješno potvrđena"
                    });
                }

                _domainNotifications.StageCustomerNotification(
                    payment.CustomerUserId,
                    "Uplata uspješna",
                    $"Vaša uplata za rental rezervaciju {reservationNumber} je uspješno obrađena.",
                    NotificationType.PaymentSucceeded,
                    relatedEntityType: "Payment",
                    relatedEntityId: payment.Id);

                await _domainNotifications.StageStaffOperationalNotificationsAsync(
                    "Uplata primljena",
                    $"Uplata u iznosu od {payment.Amount:F2} {payment.Currency} za rental rezervaciju {reservationNumber} je uspješno obrađena.",
                    NotificationType.PaymentSucceeded,
                    relatedEntityType: "Payment",
                    relatedEntityId: payment.Id);
            }
        }

        await _ledger.RecordPaymentCaptureAsync(payment, reservationNumber);
    }

    private async Task ApplyFailedPaymentAsync(Payment payment, PaymentIntent paymentIntent, DateTime now)
    {
        payment.Status = PaymentStatus.Failed;
        payment.FailedReason = paymentIntent.LastPaymentError?.Message
            ?? "Plaćanje nije uspjelo.";
        payment.UpdatedAtUtc = now;

        var reservationNumber = payment.RentalReservation?.ReservationNumber ?? "N/A";

        _domainNotifications.StageCustomerNotification(
            payment.CustomerUserId,
            "Uplata neuspješna",
            $"Uplata za rental rezervaciju {reservationNumber} nije uspjela." +
                (string.IsNullOrWhiteSpace(payment.FailedReason) ? string.Empty : $" Razlog: {payment.FailedReason}"),
            NotificationType.PaymentFailed,
            relatedEntityType: "Payment",
            relatedEntityId: payment.Id);
    }

    private static PaymentStatus MapStripeStatus(PaymentIntent paymentIntent)
    {
        return paymentIntent.Status switch
        {
            "succeeded" => PaymentStatus.Succeeded,
            "processing" or "requires_capture" => PaymentStatus.Processing,
            "requires_action" or "requires_confirmation" => PaymentStatus.RequiresAction,
            "canceled" => PaymentStatus.Cancelled,
            "requires_payment_method" when paymentIntent.LastPaymentError != null => PaymentStatus.Failed,
            "requires_payment_method" => PaymentStatus.Created,
            _ => PaymentStatus.Created
        };
    }

    private static bool IsTerminalPaymentStatus(PaymentStatus status)
    {
        return status is PaymentStatus.Succeeded
            or PaymentStatus.Failed
            or PaymentStatus.Cancelled
            or PaymentStatus.Expired;
    }

    private static PaymentStatusResponse BuildStatusResponse(
        Payment payment, PaymentIntent paymentIntent, bool syncApplied)
    {
        var mappedStripeStatus = MapStripeStatus(paymentIntent);
        var rentalStatus = payment.RentalReservation?.Status;

        return new PaymentStatusResponse
        {
            PaymentId = payment.Id,
            LocalStatus = payment.Status,
            LocalStatusLabel = payment.Status.ToString(),
            StripeStatus = paymentIntent.Status,
            ProviderPaymentIntentId = payment.ProviderPaymentIntentId,
            RentalReservationStatus = rentalStatus,
            RentalReservationStatusLabel = rentalStatus?.ToString(),
            IsInSync = payment.Status == mappedStripeStatus,
            SyncApplied = syncApplied,
            Payment = MapToResponse(payment)
        };
    }
}
