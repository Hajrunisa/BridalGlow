using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public class FinancialLedgerService : IFinancialLedgerService
{
    private readonly BridalGlowDbContext _context;

    public FinancialLedgerService(BridalGlowDbContext context)
    {
        _context = context;
    }

    public async Task RecordPaymentCaptureAsync(Payment payment, string? reservationNumber = null)
    {
        var alreadyRecorded = await _context.TransactionLedgerEntries
            .AnyAsync(e => e.PaymentId == payment.Id
                        && e.EntryType == LedgerEntryType.PaymentCapture
                        && !e.IsDeleted);

        if (alreadyRecorded)
            return;

        var amount = payment.CapturedAmount > 0m ? payment.CapturedAmount : payment.Amount;
        var occurredAt = payment.PaidAtUtc ?? DateTime.UtcNow;
        var reservationLabel = string.IsNullOrWhiteSpace(reservationNumber)
            ? payment.RentalReservationId?.ToString() ?? "N/A"
            : reservationNumber;

        var entry = new TransactionLedgerEntry
        {
            PaymentId = payment.Id,
            RentalReservationId = payment.RentalReservationId,
            EntryType = LedgerEntryType.PaymentCapture,
            Direction = LedgerDirection.Credit,
            Amount = amount,
            Currency = payment.Currency,
            OccurredAtUtc = occurredAt,
            Description = $"Payment capture for rental reservation {reservationLabel}",
            ExternalReference = payment.ProviderChargeId ?? payment.ProviderPaymentIntentId,
            CreatedAtUtc = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.TransactionLedgerEntries.Add(entry);
    }

    public async Task RecordRefundAsync(Refund refund, Payment payment, string? reservationNumber = null)
    {
        var alreadyRecorded = await _context.TransactionLedgerEntries
            .AnyAsync(e => e.RefundId == refund.Id
                        && e.EntryType == LedgerEntryType.Refund
                        && !e.IsDeleted);

        if (alreadyRecorded)
            return;

        var reservationLabel = string.IsNullOrWhiteSpace(reservationNumber)
            ? payment.RentalReservationId?.ToString() ?? "N/A"
            : reservationNumber;

        var entry = new TransactionLedgerEntry
        {
            PaymentId = payment.Id,
            RefundId = refund.Id,
            RentalReservationId = payment.RentalReservationId,
            EntryType = LedgerEntryType.Refund,
            Direction = LedgerDirection.Debit,
            Amount = refund.Amount,
            Currency = refund.Currency,
            OccurredAtUtc = refund.ProcessedAtUtc ?? DateTime.UtcNow,
            Description = $"Refund for rental reservation {reservationLabel}",
            ExternalReference = refund.ProviderRefundId,
            CreatedAtUtc = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.TransactionLedgerEntries.Add(entry);
    }

    public async Task<LedgerReportResponse> GetLedgerAsync(DateTime? fromUtc, DateTime? toUtc)
    {
        var query = _context.TransactionLedgerEntries
            .Include(e => e.Payment)
                .ThenInclude(p => p!.Customer)
            .Include(e => e.Payment)
                .ThenInclude(p => p!.RentalReservation)
            .Include(e => e.RentalReservation)
            .Where(e => !e.IsDeleted);

        if (fromUtc.HasValue)
            query = query.Where(e => e.OccurredAtUtc >= fromUtc.Value);

        if (toUtc.HasValue)
            query = query.Where(e => e.OccurredAtUtc <= toUtc.Value);

        var captureEntries = await query
            .Where(e => e.EntryType == LedgerEntryType.PaymentCapture
                     && e.Direction == LedgerDirection.Credit)
            .ToListAsync();

        var entries = await query
            .OrderByDescending(e => e.OccurredAtUtc)
            .ThenByDescending(e => e.Id)
            .ToListAsync();

        var primaryCurrency = captureEntries.FirstOrDefault()?.Currency ?? "EUR";

        return new LedgerReportResponse
        {
            FromUtc = fromUtc,
            ToUtc = toUtc,
            Summary = new LedgerPeriodSummary
            {
                TotalReceivedAmount = captureEntries.Sum(e => e.Amount),
                TransactionCount = captureEntries.Count,
                Currency = primaryCurrency
            },
            Entries = entries.Select(MapToResponse).ToList()
        };
    }

    private static TransactionLedgerEntryResponse MapToResponse(TransactionLedgerEntry entity)
    {
        var reservation = entity.RentalReservation ?? entity.Payment?.RentalReservation;
        var customer = entity.Payment?.Customer;

        return new TransactionLedgerEntryResponse
        {
            Id = entity.Id,
            PaymentId = entity.PaymentId,
            RefundId = entity.RefundId,
            RentalReservationId = entity.RentalReservationId,
            EntryType = entity.EntryType,
            EntryTypeLabel = entity.EntryType.ToString(),
            Direction = entity.Direction,
            DirectionLabel = entity.Direction.ToString(),
            Amount = entity.Amount,
            Currency = entity.Currency,
            OccurredAtUtc = entity.OccurredAtUtc,
            Description = entity.Description,
            ExternalReference = entity.ExternalReference,
            ReservationNumber = reservation?.ReservationNumber,
            CustomerName = customer != null
                ? $"{customer.FirstName} {customer.LastName}".Trim()
                : null,
            CreatedAtUtc = entity.CreatedAtUtc
        };
    }
}
