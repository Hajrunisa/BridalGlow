namespace BridalGlow.Services.Helpers;

public class RecommenderOptions
{
    public const string SectionName = "Recommender";

    public string ModelVersion { get; set; } = "ibcf-v1";

    public int TopKSimilarDresses { get; set; } = 10;

    public int TopKRecommendations { get; set; } = 12;

    public decimal MinSimilarityScore { get; set; } = 0.01m;

    public int ViewDeduplicationMinutes { get; set; } = 30;

    public int SimilarityRecomputeIntervalHours { get; set; } = 24;

    public int SnapshotRecomputeIntervalHours { get; set; } = 6;

    public RecommenderInteractionWeightOptions InteractionWeights { get; set; } = new();
}

public class RecommenderInteractionWeightOptions
{
    public decimal View { get; set; } = 1m;

    public decimal Favorite { get; set; } = 2m;

    public decimal TryOnReserved { get; set; } = 3m;

    public decimal RentalReserved { get; set; } = 4m;

    public decimal ReviewSubmitted { get; set; } = 5m;
}
