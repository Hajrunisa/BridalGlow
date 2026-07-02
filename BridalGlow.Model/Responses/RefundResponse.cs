using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class RefundResponse
{
    public int Id { get; set; }
    public int PaymentId { get; set; }
    public int RequestedByUserId { get; set; }
    public int? ApprovedByUserId { get; set; }
    public RefundStatus Status { get; set; }
    public string StatusLabel { get; set; } = string.Empty;
    public RefundReasonCode ReasonCode { get; set; }
    public string ReasonCodeLabel { get; set; } = string.Empty;
    public string? ReasonText { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "EUR";
    public string? ProviderRefundId { get; set; }
    public DateTime RequestedAtUtc { get; set; }
    public DateTime? ApprovedAtUtc { get; set; }
    public DateTime? ProcessedAtUtc { get; set; }
    public DateTime? RejectedAtUtc { get; set; }
    public string? FailureReason { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}
