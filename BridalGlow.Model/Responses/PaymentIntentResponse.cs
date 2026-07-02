namespace BridalGlow.Model.Responses;

public class PaymentIntentResponse
{
    public int PaymentId { get; set; }
    public string ClientSecret { get; set; } = string.Empty;
    public string EphemeralKey { get; set; } = string.Empty;
    public string CustomerId { get; set; } = string.Empty;
}
