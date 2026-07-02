using System;
using System.Collections.Generic;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class RentalReservationResponse
{
    public int Id { get; set; }
    public string ReservationNumber { get; set; } = string.Empty;

    public int DressId { get; set; }
    public string DressName { get; set; } = string.Empty;
    public string DressCode { get; set; } = string.Empty;

    public int CustomerUserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;

    public DateTime StartDateUtc { get; set; }
    public DateTime EndDateUtc { get; set; }

    public RentalReservationStatus Status { get; set; }
    public string StatusLabel { get; set; } = string.Empty;

    public decimal BaseAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal DepositAmount { get; set; }
    public decimal LateFeeAmount { get; set; }
    public decimal DamageFeeAmount { get; set; }
    public decimal TotalAmount { get; set; }
    public string Currency { get; set; } = "EUR";

    public string? Notes { get; set; }
    public string? CancellationReason { get; set; }

    public DateTime? CancelledAtUtc { get; set; }
    public DateTime? ApprovedAtUtc { get; set; }
    public DateTime? PickedUpAtUtc { get; set; }
    public DateTime? ReturnedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }

    public List<RentalReservationStatusHistoryResponse> StatusHistory { get; set; } = new();
}
