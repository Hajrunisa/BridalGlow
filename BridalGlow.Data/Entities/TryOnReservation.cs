using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class TryOnReservation : AuditableEntity
{
    public string ReservationNumber { get; set; } = string.Empty;
    public int DressId { get; set; }
    public int CustomerUserId { get; set; }
    public DateTime StartAtUtc { get; set; }
    public DateTime EndAtUtc { get; set; }
    public TryOnReservationStatus Status { get; set; }
    public decimal PriceAmount { get; set; }
    public decimal? DepositAmount { get; set; }
    public string? Notes { get; set; }
    public string? CancellationReason { get; set; }
    public DateTime? CancelledAtUtc { get; set; }
    public DateTime? ConfirmedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
    public DateTime? NoShowAtUtc { get; set; }

    public Dress Dress { get; set; } = null!;
    public User Customer { get; set; } = null!;
    public ICollection<TryOnReservationStatusHistory> StatusHistory { get; set; } = new List<TryOnReservationStatusHistory>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
}
