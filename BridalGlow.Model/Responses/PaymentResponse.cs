using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class PaymentResponse
{
    public int Id { get; set; }
    public int? RentalReservationId { get; set; }
    public int? TryOnReservationId { get; set; }
    public int CustomerUserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;

    public PaymentType PaymentType { get; set; }
    public string PaymentTypeLabel { get; set; } = string.Empty;
    public PaymentStatus Status { get; set; }
    public string StatusLabel { get; set; } = string.Empty;
    public PaymentProvider Provider { get; set; }
    public string ProviderLabel { get; set; } = string.Empty;

    public string? ProviderPaymentIntentId { get; set; }
    public string? ProviderChargeId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "EUR";
    public decimal CapturedAmount { get; set; }
    public string? FailedReason { get; set; }
    public DateTime? PaidAtUtc { get; set; }
    public DateTime? ExpiresAtUtc { get; set; }

    public string? ReservationNumber { get; set; }
    public string? DressName { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}
