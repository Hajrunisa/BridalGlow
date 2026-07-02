using System.Diagnostics;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BridalGlow.Worker.Services;

/// <summary>
/// Periodically runs recommendation snapshot recompute after the similarity model is available.
/// </summary>
public class RecommendationSnapshotHostedService : BackgroundService
{
    private static readonly TimeSpan InitialOffset = TimeSpan.FromMinutes(15);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IOptions<RecommenderOptions> _options;
    private readonly ILogger<RecommendationSnapshotHostedService> _logger;

    public RecommendationSnapshotHostedService(
        IServiceScopeFactory scopeFactory,
        IOptions<RecommenderOptions> options,
        ILogger<RecommendationSnapshotHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var intervalHours = Math.Max(1, _options.Value.SnapshotRecomputeIntervalHours);
        var pollInterval = TimeSpan.FromHours(intervalHours);

        _logger.LogInformation(
            "Recommendation snapshot scheduler started (initial offset {OffsetMinutes}m, interval {IntervalHours}h).",
            InitialOffset.TotalMinutes,
            intervalHours);

        try
        {
            await Task.Delay(InitialOffset, stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            return;
        }

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
                _logger.LogError(ex, "Recommendation snapshot scheduler encountered an error.");
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

        _logger.LogInformation("Recommendation snapshot scheduler stopped.");
    }

    private async Task RunScheduledRecomputeAsync(CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();
        _logger.LogInformation(
            "Snapshot recompute job started. Job={JobName} Trigger={Trigger}",
            nameof(RecommendationSnapshotHostedService),
            "Scheduled");

        try
        {
            using var scope = _scopeFactory.CreateScope();
            var snapshotService = scope.ServiceProvider.GetRequiredService<IRecommendationSnapshotService>();

            var snapshotCount = await snapshotService.RecomputeSnapshotsAsync(cancellationToken);

            _logger.LogInformation(
                "Snapshot recompute job finished. Job={JobName} Trigger={Trigger} DurationMs={DurationMs} ProcessedRecords={ProcessedRecords} Success={Success}",
                nameof(RecommendationSnapshotHostedService),
                "Scheduled",
                stopwatch.ElapsedMilliseconds,
                snapshotCount,
                true);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Snapshot recompute job failed. Job={JobName} Trigger={Trigger} DurationMs={DurationMs} Success={Success}",
                nameof(RecommendationSnapshotHostedService),
                "Scheduled",
                stopwatch.ElapsedMilliseconds,
                false);
            throw;
        }
    }
}
