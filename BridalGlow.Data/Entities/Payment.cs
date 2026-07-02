using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class Payment : AuditableEntity
{
    public int? RentalReservationId { get; set; }
    public int? TryOnReservationId { get; set; }
    public int CustomerUserId { get; set; }
    public PaymentType PaymentType { get; set; }
    public PaymentStatus Status { get; set; }
    public PaymentProvider Provider { get; set; }
    public string? ProviderPaymentIntentId { get; set; }
    public string? ProviderChargeId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "EUR";
    public decimal CapturedAmount { get; set; }
    public string? FailedReason { get; set; }
    public DateTime? PaidAtUtc { get; set; }
    public DateTime? ExpiresAtUtc { get; set; }
    public string? MetadataJson { get; set; }

    public RentalReservation? RentalReservation { get; set; }
    public TryOnReservation? TryOnReservation { get; set; }
    public User Customer { get; set; } = null!;
    public ICollection<Refund> Refunds { get; set; } = new List<Refund>();
    public ICollection<TransactionLedgerEntry> LedgerEntries { get; set; } = new List<TransactionLedgerEntry>();
}
