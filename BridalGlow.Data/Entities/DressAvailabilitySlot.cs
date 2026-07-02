using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class DressAvailabilitySlot : AuditableEntity
{
    public int DressId { get; set; }
    public DateTime StartAtUtc { get; set; }
    public DateTime EndAtUtc { get; set; }
    public AvailabilitySlotType SlotType { get; set; }
    public string? Reason { get; set; }
    public int? SourceReservationId { get; set; }
    public ReservationSourceType? SourceReservationType { get; set; }

    public Dress Dress { get; set; } = null!;
}
