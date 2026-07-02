using Microsoft.Extensions.Configuration;

namespace BridalGlow.Services.Helpers;

public static class RabbitMqSettingsResolver
{
    public static RabbitMqSettings Resolve(IConfiguration? configuration = null)
    {
        var host = FirstNonEmpty(
            Environment.GetEnvironmentVariable("RABBITMQ_HOST"),
            configuration?["RabbitMQ:Host"])
            ?? "localhost";

        var portValue = FirstNonEmpty(
            Environment.GetEnvironmentVariable("RABBITMQ_PORT"),
            configuration?["RabbitMQ:Port"]);

        int? port = null;
        if (!string.IsNullOrWhiteSpace(portValue) && int.TryParse(portValue, out var parsedPort))
            port = parsedPort;

        // Local docker-compose maps AMQP to host port 5673 (see .env.example / docker-compose.yml).
        if (!port.HasValue && IsLocalHost(host))
            port = 5673;

        return new RabbitMqSettings
        {
            Host = host,
            Port = port,
            Username = FirstNonEmpty(
                Environment.GetEnvironmentVariable("RABBITMQ_USERNAME"),
                configuration?["RabbitMQ:Username"])
                ?? "guest",
            Password = FirstNonEmpty(
                Environment.GetEnvironmentVariable("RABBITMQ_PASSWORD"),
                configuration?["RabbitMQ:Password"])
                ?? "guest",
            VirtualHost = FirstNonEmpty(
                Environment.GetEnvironmentVariable("RABBITMQ_VIRTUALHOST"),
                configuration?["RabbitMQ:VirtualHost"])
                ?? "/"
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

    private static bool IsLocalHost(string host) =>
        host.Equals("localhost", StringComparison.OrdinalIgnoreCase)
        || host == "127.0.0.1";
}
