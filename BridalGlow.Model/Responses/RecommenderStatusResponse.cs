using System;

namespace BridalGlow.Model.Responses;

public class RecommenderStatusResponse
{
    public string ModelVersion { get; set; } = string.Empty;

    public DateTime? LastSimilarityRunAtUtc { get; set; }

    public DateTime? LastSnapshotRunAtUtc { get; set; }

    public int InteractionCount { get; set; }

    public int SimilarityPairCount { get; set; }

    public int SnapshotCount { get; set; }
}
