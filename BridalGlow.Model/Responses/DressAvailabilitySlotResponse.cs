using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class DressAvailabilitySlotResponse
{
    public int Id { get; set; }
    public int DressId { get; set; }
    public string DressName { get; set; } = string.Empty;
    public string DressCode { get; set; } = string.Empty;
    public DateTime StartAtUtc { get; set; }
    public DateTime EndAtUtc { get; set; }
    public AvailabilitySlotType SlotType { get; set; }
    public string? Reason { get; set; }
    public int? SourceReservationId { get; set; }
    public ReservationSourceType? SourceReservationType { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}
