using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class RentalReservationStatusHistory
{
    public int Id { get; set; }
    public int RentalReservationId { get; set; }
    public int ChangedByUserId { get; set; }
    public RentalReservationStatus FromStatus { get; set; }
    public RentalReservationStatus ToStatus { get; set; }
    public DateTime ChangedAtUtc { get; set; }
    public string? Reason { get; set; }

    public RentalReservation RentalReservation { get; set; } = null!;
    public User ChangedByUser { get; set; } = null!;
}
