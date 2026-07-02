using System.Text;
using Microsoft.Extensions.Configuration;

namespace BridalGlow.Services.Helpers;

public static class JwtSecretResolver
{
    public static string ResolveSecretKey(IConfiguration? configuration = null)
    {
        var secretKey = Environment.GetEnvironmentVariable("JWT__SECRET_KEY");

        if (string.IsNullOrWhiteSpace(secretKey) && configuration != null)
            secretKey = configuration["Jwt:SecretKey"];

        if (string.IsNullOrWhiteSpace(secretKey))
            throw new InvalidOperationException(
                "JWT secret key is not configured. Set JWT__SECRET_KEY or Jwt:SecretKey.");

        if (Encoding.UTF8.GetByteCount(secretKey) < 32)
            throw new InvalidOperationException(
                "JWT secret key must be at least 32 bytes (256 bits) for HS256.");

        return secretKey;
    }

    public static string ResolveIssuer(IConfiguration? configuration = null) =>
        FirstNonEmpty(
            Environment.GetEnvironmentVariable("JWT__ISSUER"),
            configuration?["Jwt:Issuer"])
        ?? "BridalGlow";

    public static string ResolveAudience(IConfiguration? configuration = null) =>
        FirstNonEmpty(
            Environment.GetEnvironmentVariable("JWT__AUDIENCE"),
            configuration?["Jwt:Audience"])
        ?? "BridalGlow";

    private static string? FirstNonEmpty(params string?[] values)
    {
        foreach (var value in values)
        {
            if (!string.IsNullOrWhiteSpace(value))
                return value;
        }

        return null;
    }
}
