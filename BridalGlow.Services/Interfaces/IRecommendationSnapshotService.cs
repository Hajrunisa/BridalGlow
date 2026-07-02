namespace BridalGlow.Services.Interfaces;

public interface IRecommendationSnapshotService
{
    Task<int> RecomputeSnapshotsAsync(CancellationToken cancellationToken = default);
}
