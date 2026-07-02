using Microsoft.Extensions.Configuration;

namespace BridalGlow.Services.Helpers;

public static class SmtpSettingsResolver
{
    public static SmtpSettings Resolve(IConfiguration? configuration = null)
    {
        var portValue = FirstNonEmpty(
            Environment.GetEnvironmentVariable("SMTP__PORT"),
            configuration?["SMTP:Port"]);

        int port = 587;
        if (!string.IsNullOrWhiteSpace(portValue) && int.TryParse(portValue, out var parsedPort))
            port = parsedPort;

        var useSslValue = FirstNonEmpty(
            Environment.GetEnvironmentVariable("SMTP__USE_SSL"),
            configuration?["SMTP:UseSsl"]);

        return new SmtpSettings
        {
            Host = FirstNonEmpty(
                Environment.GetEnvironmentVariable("SMTP__HOST"),
                configuration?["SMTP:Host"]),
            Port = port,
            Email = FirstNonEmpty(
                Environment.GetEnvironmentVariable("SMTP__EMAIL"),
                configuration?["SMTP:Email"]),
            Password = FirstNonEmpty(
                Environment.GetEnvironmentVariable("SMTP__PASSWORD"),
                configuration?["SMTP:Password"]),
            UseSsl = !string.Equals(useSslValue, "false", StringComparison.OrdinalIgnoreCase)
        };
    }

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
