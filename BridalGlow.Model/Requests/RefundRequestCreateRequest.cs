using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Requests;

public class RefundRequestCreateRequest
{
    public int PaymentId { get; set; }
    public RefundReasonCode ReasonCode { get; set; }
    public string? ReasonText { get; set; }
    public decimal? Amount { get; set; }
}
