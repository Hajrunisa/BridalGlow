using System;

namespace BridalGlow.Model.Requests;

public class TryOnReservationCreateRequest
{
    public int DressId { get; set; }

    /// <summary>
    /// The DressAvailabilitySlot ID (type=Available) the customer selected.
    /// </summary>
    public int AvailabilitySlotId { get; set; }

    /// <summary>
    /// The specific date the customer is booking the appointment for.
    /// When the selected Available slot spans multiple days (e.g. an entire month),
    /// this date is used to restrict the TryOnHold to just the booked day,
    /// so that other days within the same slot remain available for other customers.
    /// </summary>
    public DateTime? AppointmentDate { get; set; }

    public string? Notes { get; set; }
}
