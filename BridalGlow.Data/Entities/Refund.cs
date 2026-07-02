using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class Refund : AuditableEntity
{
    public int PaymentId { get; set; }
    public int RequestedByUserId { get; set; }
    public int? ApprovedByUserId { get; set; }
    public RefundStatus Status { get; set; }
    public RefundReasonCode ReasonCode { get; set; }
    public string? ReasonText { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "EUR";
    public string? ProviderRefundId { get; set; }
    public DateTime RequestedAtUtc { get; set; }
    public DateTime? ApprovedAtUtc { get; set; }
    public DateTime? ProcessedAtUtc { get; set; }
    public DateTime? RejectedAtUtc { get; set; }
    public string? FailureReason { get; set; }

    public Payment Payment { get; set; } = null!;
    public User RequestedByUser { get; set; } = null!;
    public User? ApprovedByUser { get; set; }
    public ICollection<TransactionLedgerEntry> LedgerEntries { get; set; } = new List<TransactionLedgerEntry>();
}
