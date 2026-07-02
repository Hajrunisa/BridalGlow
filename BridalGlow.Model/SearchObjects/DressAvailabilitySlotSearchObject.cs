using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.SearchObjects;

public class DressAvailabilitySlotSearchObject : BaseSearchObject
{
    public int? DressId { get; set; }
    public DateTime? From { get; set; }
    public DateTime? To { get; set; }
    public AvailabilitySlotType? SlotType { get; set; }
}
