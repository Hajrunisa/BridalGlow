namespace BridalGlow.Services.Interfaces;

/// <summary>
/// Reads pending outbox rows and publishes them to RabbitMQ.
/// </summary>
public interface IOutboxRelayService
{
    Task<int> PublishPendingMessagesAsync(CancellationToken cancellationToken = default);
}
