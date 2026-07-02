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
/// Consumes similarity recompute requests from RabbitMQ and runs the offline computation.
/// </summary>
public class SimilarityRecomputeConsumerHostedService : BackgroundService
{
    private readonly IBus _bus;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SimilarityRecomputeConsumerHostedService> _logger;

    public SimilarityRecomputeConsumerHostedService(
        IBus bus,
        IServiceScopeFactory scopeFactory,
        ILogger<SimilarityRecomputeConsumerHostedService> logger)
    {
        _bus = bus;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation(
            "Similarity recompute consumer subscribing to '{SubscriptionId}'.",
            MessagingConstants.SimilarityRecomputeSubscriptionId);

        await _bus.PubSub.SubscribeAsync<SimilarityRecomputeRequestedMessage>(
            MessagingConstants.SimilarityRecomputeSubscriptionId,
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

        _logger.LogInformation("Similarity recompute consumer stopped.");
    }

    private async Task HandleRecomputeRequestAsync(SimilarityRecomputeRequestedMessage message)
    {
        var stopwatch = Stopwatch.StartNew();
        _logger.LogInformation(
            "Similarity recompute job started. Job={JobName} Trigger={Trigger} Source={Source} RequestedByUserId={RequestedByUserId}",
            nameof(SimilarityRecomputeConsumerHostedService),
            "RabbitMQ",
            message.Source,
            message.RequestedByUserId);

        try
        {
            using var scope = _scopeFactory.CreateScope();
            var computationService =
                scope.ServiceProvider.GetRequiredService<IDressSimilarityComputationService>();

            var pairCount = await computationService.RecomputeSimilaritiesAsync();

            _logger.LogInformation(
                "Similarity recompute job finished. Job={JobName} Trigger={Trigger} Source={Source} RequestedByUserId={RequestedByUserId} DurationMs={DurationMs} ProcessedRecords={ProcessedRecords} Success={Success}",
                nameof(SimilarityRecomputeConsumerHostedService),
                "RabbitMQ",
                message.Source,
                message.RequestedByUserId,
                stopwatch.ElapsedMilliseconds,
                pairCount,
                true);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Similarity recompute job failed. Job={JobName} Trigger={Trigger} Source={Source} RequestedByUserId={RequestedByUserId} DurationMs={DurationMs} Success={Success}",
                nameof(SimilarityRecomputeConsumerHostedService),
                "RabbitMQ",
                message.Source,
                message.RequestedByUserId,
                stopwatch.ElapsedMilliseconds,
                false);
        }
    }
}
