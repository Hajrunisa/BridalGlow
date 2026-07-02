using Microsoft.Extensions.Configuration;

namespace BridalGlow.Services.Helpers;

public static class StripeSecretResolver
{
    public static string ResolveSecretKey(IConfiguration? configuration = null)
    {
        var secretKey = Environment.GetEnvironmentVariable("STRIPE__SECRET_KEY");

        if (string.IsNullOrWhiteSpace(secretKey) && configuration != null)
            secretKey = configuration["Stripe:SecretKey"];

        if (string.IsNullOrWhiteSpace(secretKey))
            throw new InvalidOperationException(
                "Stripe secret key is not configured. Set STRIPE__SECRET_KEY or Stripe:SecretKey.");

        return secretKey;
    }
}
