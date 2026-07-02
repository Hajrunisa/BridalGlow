namespace BridalGlow.Services.Interfaces;

public interface IStripeWebhookService
{
    Task ProcessWebhookAsync(string json, string stripeSignatureHeader);
}
