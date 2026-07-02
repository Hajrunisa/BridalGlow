using EasyNetQ;
using BridalGlow.Model.Messaging;
using BridalGlow.Model.Messaging.Messages;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BridalGlow.Worker.Services;

/// <summary>
/// Subscribes to infrastructure ping messages to verify RabbitMQ consumer wiring.
/// </summary>
public class InfrastructurePingConsumerHostedService : BackgroundService
{
    private readonly IBus _bus;
    private readonly ILogger<InfrastructurePingConsumerHostedService> _logger;

    public InfrastructurePingConsumerHostedService(
        IBus bus,
        ILogger<InfrastructurePingConsumerHostedService> logger)
    {
        _bus = bus;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation(
            "Infrastructure ping consumer subscribing to '{SubscriptionId}'.",
            MessagingConstants.InfrastructureSubscriptionId);

        await _bus.PubSub.SubscribeAsync<InfrastructurePingMessage>(
            MessagingConstants.InfrastructureSubscriptionId,
            HandlePingMessageAsync,
            stoppingToken);

        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // expected on shutdown
        }

        _logger.LogInformation("Infrastructure ping consumer stopped.");
    }

    private Task HandlePingMessageAsync(InfrastructurePingMessage message)
    {
        _logger.LogInformation(
            "Received infrastructure ping from '{Source}' at {SentAtUtc}: {Message}",
            message.Source,
            message.SentAtUtc,
            message.Message);

        return Task.CompletedTask;
    }
}
