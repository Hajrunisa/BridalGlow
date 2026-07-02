using System.Diagnostics;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BridalGlow.Worker.Services;

/// <summary>
/// Periodically runs item-item dress similarity recompute in the worker process.
/// </summary>
public class DressSimilarityRecomputeHostedService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IOptions<RecommenderOptions> _options;
    private readonly ILogger<DressSimilarityRecomputeHostedService> _logger;

    public DressSimilarityRecomputeHostedService(
        IServiceScopeFactory scopeFactory,
        IOptions<RecommenderOptions> options,
        ILogger<DressSimilarityRecomputeHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var intervalHours = Math.Max(1, _options.Value.SimilarityRecomputeIntervalHours);
        var pollInterval = TimeSpan.FromHours(intervalHours);

        _logger.LogInformation(
            "Dress similarity scheduler started (interval {IntervalHours}h).",
            intervalHours);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunScheduledRecomputeAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Dress similarity scheduler encountered an error.");
            }

            try
            {
                await Task.Delay(pollInterval, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
        }

        _logger.LogInformation("Dress similarity scheduler stopped.");
    }

    private async Task RunScheduledRecomputeAsync(CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();
        _logger.LogInformation(
            "Similarity recompute job started. Job={JobName} Trigger={Trigger}",
            nameof(DressSimilarityRecomputeHostedService),
            "Scheduled");

        try
        {
            using var scope = _scopeFactory.CreateScope();
            var computationService =
                scope.ServiceProvider.GetRequiredService<IDressSimilarityComputationService>();

            var pairCount = await computationService.RecomputeSimilaritiesAsync(cancellationToken);

            _logger.LogInformation(
                "Similarity recompute job finished. Job={JobName} Trigger={Trigger} DurationMs={DurationMs} ProcessedRecords={ProcessedRecords} Success={Success}",
                nameof(DressSimilarityRecomputeHostedService),
                "Scheduled",
                stopwatch.ElapsedMilliseconds,
                pairCount,
                true);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Similarity recompute job failed. Job={JobName} Trigger={Trigger} DurationMs={DurationMs} Success={Success}",
                nameof(DressSimilarityRecomputeHostedService),
                "Scheduled",
                stopwatch.ElapsedMilliseconds,
                false);
            throw;
        }
    }
}
