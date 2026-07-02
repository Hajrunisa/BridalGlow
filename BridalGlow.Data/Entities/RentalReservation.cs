using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class RentalReservation : AuditableEntity
{
    public string ReservationNumber { get; set; } = string.Empty;
    public int DressId { get; set; }
    public int CustomerUserId { get; set; }
    public DateTime StartDateUtc { get; set; }
    public DateTime EndDateUtc { get; set; }
    public RentalReservationStatus Status { get; set; }
    public decimal BaseAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal DepositAmount { get; set; }
    public decimal LateFeeAmount { get; set; }
    public decimal DamageFeeAmount { get; set; }
    public decimal TotalAmount { get; set; }
    public string Currency { get; set; } = "EUR";
    public string? Notes { get; set; }
    public string? CancellationReason { get; set; }
    public DateTime? CancelledAtUtc { get; set; }
    public DateTime? ApprovedAtUtc { get; set; }
    public DateTime? PickedUpAtUtc { get; set; }
    public DateTime? ReturnedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }

    public Dress Dress { get; set; } = null!;
    public User Customer { get; set; } = null!;
    public ICollection<RentalReservationStatusHistory> StatusHistory { get; set; } = new List<RentalReservationStatusHistory>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
    public ICollection<TransactionLedgerEntry> LedgerEntries { get; set; } = new List<TransactionLedgerEntry>();
}
