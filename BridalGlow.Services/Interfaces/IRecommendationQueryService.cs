using BridalGlow.Model.Responses;

namespace BridalGlow.Services.Interfaces;

public interface IRecommendationQueryService
{
    Task<IReadOnlyList<RecommendationItemResponse>> GetForUserAsync(
        int userId,
        int? limit = null,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SimilarDressResponse>> GetSimilarDressesAsync(
        int dressId,
        int? limit = null,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RecommendationItemResponse>> GetColdStartAsync(
        int? limit = null,
        CancellationToken cancellationToken = default);

    Task<RecommenderStatusResponse> GetStatusAsync(
        CancellationToken cancellationToken = default);

    Task<RecommenderTrendsResponse> GetTrendsAsync(
        int? limit = null,
        CancellationToken cancellationToken = default);
}
