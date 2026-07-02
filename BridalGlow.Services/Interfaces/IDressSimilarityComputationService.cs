namespace BridalGlow.Services.Interfaces;

public interface IDressSimilarityComputationService
{
    Task<int> RecomputeSimilaritiesAsync(CancellationToken cancellationToken = default);
}
