using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class TransactionLedgerEntryResponse
{
    public int Id { get; set; }
    public int? PaymentId { get; set; }
    public int? RefundId { get; set; }
    public int? RentalReservationId { get; set; }
    public LedgerEntryType EntryType { get; set; }
    public string EntryTypeLabel { get; set; } = string.Empty;
    public LedgerDirection Direction { get; set; }
    public string DirectionLabel { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "EUR";
    public DateTime OccurredAtUtc { get; set; }
    public string Description { get; set; } = string.Empty;
    public string? ExternalReference { get; set; }
    public string? ReservationNumber { get; set; }
    public string? CustomerName { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
