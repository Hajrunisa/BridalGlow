namespace BridalGlow.Services.Helpers;

public class RabbitMqSettings
{
    public string Host { get; set; } = "localhost";
    public int? Port { get; set; }
    public string Username { get; set; } = "guest";
    public string Password { get; set; } = "guest";
    public string VirtualHost { get; set; } = "/";

    public string BuildConnectionString()
    {
        var host = Port.HasValue ? $"{Host}:{Port.Value}" : Host;
        return $"host={host};virtualHost={VirtualHost};username={Username};password={Password}";
    }
}
