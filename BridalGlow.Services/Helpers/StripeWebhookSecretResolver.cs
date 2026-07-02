using Microsoft.Extensions.Configuration;

namespace BridalGlow.Services.Helpers;

public static class StripeWebhookSecretResolver
{
    public static string ResolveWebhookSecret(IConfiguration? configuration = null)
    {
        var webhookSecret = Environment.GetEnvironmentVariable("STRIPE__WEBHOOK_SECRET");

        if (string.IsNullOrWhiteSpace(webhookSecret) && configuration != null)
            webhookSecret = configuration["Stripe:WebhookSecret"];

        if (string.IsNullOrWhiteSpace(webhookSecret))
            throw new InvalidOperationException(
                "Stripe webhook secret is not configured. Set STRIPE__WEBHOOK_SECRET or Stripe:WebhookSecret.");

        return webhookSecret;
    }
}
