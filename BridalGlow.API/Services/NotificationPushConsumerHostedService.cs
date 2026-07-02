using EasyNetQ;
using BridalGlow.API.Services;
using BridalGlow.Model.Messaging;
using BridalGlow.Model.Messaging.Messages;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BridalGlow.API.Services;

/// <summary>
/// Consumes delivered-notification events from RabbitMQ and pushes them via SignalR.
/// </summary>
public class NotificationPushConsumerHostedService : BackgroundService
{
    private static readonly TimeSpan RetryDelay = TimeSpan.FromSeconds(5);

    /// <summary>
    /// Unique per process so every API instance receives a copy of each delivered
    /// notification (EasyNetQ fanout). A shared subscription id creates one queue
    /// with competing consumers, so only one instance gets each message and push
    /// fails when that instance has no SignalR clients.
    /// </summary>
    private readonly string _subscriptionId =
        $"{MessagingConstants.NotificationPushSubscriptionId}_{Environment.ProcessId}";

    private readonly IBus _bus;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<NotificationPushConsumerHostedService> _logger;

    public NotificationPushConsumerHostedService(
        IBus bus,
        IServiceScopeFactory scopeFactory,
        ILogger<NotificationPushConsumerHostedService> logger)
    {
        _bus = bus;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Notification push consumer starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await SubscribeAndWaitAsync(stoppingToken);
                break;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (TaskCanceledException ex) when (!stoppingToken.IsCancellationRequested)
            {
                // EasyNetQ uses TaskCanceledException for internal operation timeouts
                // (e.g. broker unreachable or wrong port) — must not stop the API host.
                _logger.LogWarning(
                    ex,
                    "Notification push consumer subscribe timed out. " +
                    "Verify RabbitMQ is reachable (RABBITMQ_HOST/RABBITMQ_PORT). Retrying in {DelaySeconds}s.",
                    RetryDelay.TotalSeconds);

                await DelayBeforeRetryAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(
                    ex,
                    "Notification push consumer failed to subscribe. Retrying in {DelaySeconds}s.",
                    RetryDelay.TotalSeconds);

                await DelayBeforeRetryAsync(stoppingToken);
            }
        }

        _logger.LogInformation("Notification push consumer stopped.");
    }

    private async Task SubscribeAndWaitAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation(
            "Notification push consumer subscribing to '{SubscriptionId}'.",
            _subscriptionId);

        await _bus.PubSub.SubscribeAsync<NotificationDeliveredMessage>(
            _subscriptionId,
            HandleMessageAsync,
            stoppingToken);

        _logger.LogInformation("Notification push consumer subscribed successfully.");

        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // expected on shutdown
        }
    }

    private async Task DelayBeforeRetryAsync(CancellationToken stoppingToken)
    {
        try
        {
            await Task.Delay(RetryDelay, stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // expected on shutdown
        }
    }

    private async Task HandleMessageAsync(NotificationDeliveredMessage message)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var signalR = scope.ServiceProvider.GetRequiredService<INotificationSignalRService>();
            await signalR.PushAsync(message);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Failed to push notification {NotificationId} to user {UserId} via SignalR.",
                message.NotificationId,
                message.UserId);
        }
    }
}
