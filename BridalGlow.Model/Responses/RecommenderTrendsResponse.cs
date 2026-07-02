using System;
using System.Collections.Generic;

namespace BridalGlow.Model.Responses;

public class RecommenderTrendsResponse
{
    public string ModelVersion { get; set; } = string.Empty;

    public DateTime? LastSnapshotRunAtUtc { get; set; }

    public IReadOnlyList<RecommendationTrendItemResponse> Items { get; set; } =
        Array.Empty<RecommendationTrendItemResponse>();
}
