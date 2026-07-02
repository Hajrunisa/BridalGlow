using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Requests;

public class DressAvailabilitySlotCreateRequest
{
    public int DressId { get; set; }
    public DateTime StartAtUtc { get; set; }
    public DateTime EndAtUtc { get; set; }

    /// <summary>
    /// Staff may only create Available (1) or Blocked (2) slots manually.
    /// TryOnHold and RentalHold are managed automatically by the reservation system.
    /// </summary>
    public AvailabilitySlotType SlotType { get; set; }

    public string? Reason { get; set; }
}
