using System.Diagnostics;
using EasyNetQ;
using BridalGlow.Model.Messaging;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Services.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BridalGlow.Worker.Services;

/// <summary>
/// Consumes snapshot recompute requests from RabbitMQ and runs the offline computation.
/// </summary>
public class SnapshotRecomputeConsumerHostedService : BackgroundService
{
    private readonly IBus _bus;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SnapshotRecomputeConsumerHostedService> _logger;

    public SnapshotRecomputeConsumerHostedService(
        IBus bus,
        IServiceScopeFactory scopeFactory,
        ILogger<SnapshotRecomputeConsumerHostedService> logger)
    {
        _bus = bus;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation(
            "Snapshot recompute consumer subscribing to '{SubscriptionId}'.",
            MessagingConstants.SnapshotRecomputeSubscriptionId);

        await _bus.PubSub.SubscribeAsync<SnapshotRecomputeRequestedMessage>(
            MessagingConstants.SnapshotRecomputeSubscriptionId,
            HandleRecomputeRequestAsync,
            stoppingToken);

        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // expected on shutdown
        }

        _logger.LogInformation("Snapshot recompute consumer stopped.");
    }

    private async Task HandleRecomputeRequestAsync(SnapshotRecomputeRequestedMessage message)
    {
        var stopwatch = Stopwatch.StartNew();
        _logger.LogInformation(
            "Snapshot recompute job started. Job={JobName} Trigger={Trigger} Source={Source} RequestedByUserId={RequestedByUserId}",
            nameof(SnapshotRecomputeConsumerHostedService),
            "RabbitMQ",
            message.Source,
            message.RequestedByUserId);

        try
        {
            using var scope = _scopeFactory.CreateScope();
            var snapshotService = scope.ServiceProvider.GetRequiredService<IRecommendationSnapshotService>();

            var snapshotCount = await snapshotService.RecomputeSnapshotsAsync();

            _logger.LogInformation(
                "Snapshot recompute job finished. Job={JobName} Trigger={Trigger} Source={Source} RequestedByUserId={RequestedByUserId} DurationMs={DurationMs} ProcessedRecords={ProcessedRecords} Success={Success}",
                nameof(SnapshotRecomputeConsumerHostedService),
                "RabbitMQ",
                message.Source,
                message.RequestedByUserId,
                stopwatch.ElapsedMilliseconds,
                snapshotCount,
                true);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Snapshot recompute job failed. Job={JobName} Trigger={Trigger} Source={Source} RequestedByUserId={RequestedByUserId} DurationMs={DurationMs} Success={Success}",
                nameof(SnapshotRecomputeConsumerHostedService),
                "RabbitMQ",
                message.Source,
                message.RequestedByUserId,
                stopwatch.ElapsedMilliseconds,
                false);
        }
    }
}
