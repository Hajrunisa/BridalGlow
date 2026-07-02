using BridalGlow.Services.Helpers;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BridalGlow.Services.Extensions;

public static class RecommenderServiceCollectionExtensions
{
    public static IServiceCollection AddBridalGlowRecommender(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<RecommenderOptions>(options =>
        {
            configuration.GetSection(RecommenderOptions.SectionName).Bind(options);
            ApplyEnvironmentOverrides(options);
        });

        return services;
    }

    private static void ApplyEnvironmentOverrides(RecommenderOptions options)
    {
        ApplyIntEnv("RECOMMENDER_SIMILARITY_RECOMPUTE_INTERVAL_HOURS", value =>
            options.SimilarityRecomputeIntervalHours = value);

        ApplyIntEnv("RECOMMENDER_SNAPSHOT_RECOMPUTE_INTERVAL_HOURS", value =>
            options.SnapshotRecomputeIntervalHours = value);
    }

    private static void ApplyIntEnv(string name, Action<int> apply)
    {
        var raw = Environment.GetEnvironmentVariable(name)?.Trim();
        if (string.IsNullOrWhiteSpace(raw) || !int.TryParse(raw, out var value))
            return;

        apply(value);
    }
}
