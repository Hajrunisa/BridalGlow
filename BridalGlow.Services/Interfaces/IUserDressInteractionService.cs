using BridalGlow.Model.Enums;

namespace BridalGlow.Services.Interfaces;

public interface IUserDressInteractionService
{
    Task RecordInteractionAsync(
        int userId,
        int dressId,
        InteractionType interactionType,
        InteractionSource source,
        decimal? weight = null,
        string? sessionId = null,
        string? metadataJson = null,
        CancellationToken cancellationToken = default);

    Task RemoveFavoriteAsync(
        int userId,
        int dressId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<int>> GetFavoriteDressIdsAsync(
        int userId,
        CancellationToken cancellationToken = default);
}
