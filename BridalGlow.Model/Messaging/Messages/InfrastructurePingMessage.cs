using System;

namespace BridalGlow.Model.Messaging.Messages;

/// <summary>
/// Test/infrastructure message used to verify outbox → RabbitMQ → worker pipeline.
/// </summary>
public class InfrastructurePingMessage
{
    public string Message { get; set; } = string.Empty;
    public DateTime SentAtUtc { get; set; }
    public string Source { get; set; } = string.Empty;
}
