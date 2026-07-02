using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class RentalReservationStatusHistoryResponse
{
    public int Id { get; set; }
    public RentalReservationStatus FromStatus { get; set; }
    public string FromStatusLabel { get; set; } = string.Empty;
    public RentalReservationStatus ToStatus { get; set; }
    public string ToStatusLabel { get; set; } = string.Empty;
    public int ChangedByUserId { get; set; }
    public string ChangedByUserName { get; set; } = string.Empty;
    public DateTime ChangedAtUtc { get; set; }
    public string? Reason { get; set; }
}
