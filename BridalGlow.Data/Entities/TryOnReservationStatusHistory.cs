using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class TryOnReservationStatusHistory
{
    public int Id { get; set; }
    public int TryOnReservationId { get; set; }
    public int ChangedByUserId { get; set; }
    public TryOnReservationStatus FromStatus { get; set; }
    public TryOnReservationStatus ToStatus { get; set; }
    public DateTime ChangedAtUtc { get; set; }
    public string? Reason { get; set; }

    public TryOnReservation TryOnReservation { get; set; } = null!;
    public User ChangedByUser { get; set; } = null!;
}
