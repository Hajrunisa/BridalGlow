using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class TryOnReservationStatusHistoryResponse
{
    public int Id { get; set; }
    public TryOnReservationStatus FromStatus { get; set; }
    public string FromStatusLabel { get; set; } = string.Empty;
    public TryOnReservationStatus ToStatus { get; set; }
    public string ToStatusLabel { get; set; } = string.Empty;
    public int ChangedByUserId { get; set; }
    public string ChangedByUserName { get; set; } = string.Empty;
    public DateTime ChangedAtUtc { get; set; }
    public string? Reason { get; set; }
}
