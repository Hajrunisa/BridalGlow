using System;

namespace BridalGlow.Model.Requests;

public class RentalReservationCreateRequest
{
    public int DressId { get; set; }
    public DateTime StartDateUtc { get; set; }
    public DateTime EndDateUtc { get; set; }
    public string? Notes { get; set; }
}
