using System;
using System.Collections.Generic;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class TryOnReservationResponse
{
    public int Id { get; set; }
    public string ReservationNumber { get; set; } = string.Empty;

    public int DressId { get; set; }
    public string DressName { get; set; } = string.Empty;
    public string DressCode { get; set; } = string.Empty;

    public int CustomerUserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;

    public DateTime StartAtUtc { get; set; }
    public DateTime EndAtUtc { get; set; }

    public TryOnReservationStatus Status { get; set; }
    public string StatusLabel { get; set; } = string.Empty;

    public decimal PriceAmount { get; set; }
    public decimal? DepositAmount { get; set; }

    public string? Notes { get; set; }
    public string? CancellationReason { get; set; }

    public DateTime? CancelledAtUtc { get; set; }
    public DateTime? ConfirmedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
    public DateTime? NoShowAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }

    public List<TryOnReservationStatusHistoryResponse> StatusHistory { get; set; } = new();
}
