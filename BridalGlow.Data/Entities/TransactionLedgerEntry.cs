using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class TransactionLedgerEntry : AuditableEntity
{
    public int? PaymentId { get; set; }
    public int? RefundId { get; set; }
    public int? RentalReservationId { get; set; }
    public LedgerEntryType EntryType { get; set; }
    public LedgerDirection Direction { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "EUR";
    public DateTime OccurredAtUtc { get; set; }
    public string Description { get; set; } = string.Empty;
    public string? ExternalReference { get; set; }

    public Payment? Payment { get; set; }
    public Refund? Refund { get; set; }
    public RentalReservation? RentalReservation { get; set; }
}
