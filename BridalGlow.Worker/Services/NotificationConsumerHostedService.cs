using EasyNetQ;
using BridalGlow.Model.Messaging;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Services.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BridalGlow.Worker.Services;

/// <summary>
/// Consumes notification requests from RabbitMQ and persists/delivers them.
/// </summary>
public class NotificationConsumerHostedService : BackgroundService
{
    private readonly IBus _bus;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<NotificationConsumerHostedService> _logger;

    public NotificationConsumerHostedService(
        IBus bus,
        IServiceScopeFactory scopeFactory,
        ILogger<NotificationConsumerHostedService> logger)
    {
        _bus = bus;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation(
            "Notification consumer subscribing to '{SubscriptionId}'.",
            MessagingConstants.NotificationSubscriptionId);

        await _bus.PubSub.SubscribeAsync<NotificationRequestedMessage>(
            MessagingConstants.NotificationSubscriptionId,
            HandleNotificationAsync,
            stoppingToken);

        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // expected on shutdown
        }

        _logger.LogInformation("Notification consumer stopped.");
    }

    private async Task HandleNotificationAsync(NotificationRequestedMessage message)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var delivery = scope.ServiceProvider.GetRequiredService<INotificationDeliveryService>();
            await delivery.ProcessAsync(message);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Failed to process notification request for user {UserId}, type {Type}.",
                message.UserId,
                message.Type);
        }
    }
}
