using BridalGlow.Data.Database;
using BridalGlow.Services.Interfaces;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace BridalGlow.API.Health;

public class BridalGlowHealthCheck : IHealthCheck
{
    private readonly IServiceScopeFactory _scopeFactory;

    public BridalGlowHealthCheck(IServiceScopeFactory scopeFactory)
    {
        _scopeFactory = scopeFactory;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BridalGlowDbContext>();

        var canConnect = await db.Database.CanConnectAsync(cancellationToken);
        if (!canConnect)
        {
            return HealthCheckResult.Unhealthy(
                "Database connection failed.",
                data: new Dictionary<string, object> { ["databaseConnected"] = false });
        }

        var recommender = scope.ServiceProvider.GetRequiredService<IRecommendationQueryService>();
        var status = await recommender.GetStatusAsync(cancellationToken);

        return HealthCheckResult.Healthy(
            "BridalGlow API is operational.",
            data: new Dictionary<string, object>
            {
                ["databaseConnected"] = true,
                ["recommenderModelVersion"] = status.ModelVersion,
                ["recommenderLastSimilarityRunAtUtc"] = status.LastSimilarityRunAtUtc?.ToString("O") ?? string.Empty,
                ["recommenderLastSnapshotRunAtUtc"] = status.LastSnapshotRunAtUtc?.ToString("O") ?? string.Empty,
                ["recommenderInteractionCount"] = status.InteractionCount,
                ["recommenderSimilarityPairCount"] = status.SimilarityPairCount,
                ["recommenderSnapshotCount"] = status.SnapshotCount
            });
    }
}
