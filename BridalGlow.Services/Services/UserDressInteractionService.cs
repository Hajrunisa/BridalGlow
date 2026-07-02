using System.Text.Json;
using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BridalGlow.Services.Services;

public class UserDressInteractionService : IUserDressInteractionService
{
    private readonly BridalGlowDbContext _context;
    private readonly IOptions<RecommenderOptions> _options;
    private readonly ILogger<UserDressInteractionService> _logger;

    public UserDressInteractionService(
        BridalGlowDbContext context,
        IOptions<RecommenderOptions> options,
        ILogger<UserDressInteractionService> logger)
    {
        _context = context;
        _options = options;
        _logger = logger;
    }

    public async Task RecordInteractionAsync(
        int userId,
        int dressId,
        InteractionType interactionType,
        InteractionSource source,
        decimal? weight = null,
        string? sessionId = null,
        string? metadataJson = null,
        CancellationToken cancellationToken = default)
    {
        await ValidateDressAsync(dressId, cancellationToken);

        if (interactionType == InteractionType.View &&
            await IsDuplicateViewAsync(userId, dressId, sessionId, cancellationToken))
        {
            _logger.LogDebug(
                "Preskočen dupli View (user {UserId}, dress {DressId}, session {SessionId}).",
                userId, dressId, sessionId);
            return;
        }

        if (interactionType == InteractionType.Favorite &&
            await HasActiveFavoriteAsync(userId, dressId, cancellationToken))
        {
            _logger.LogDebug(
                "Preskočen dupli Favorite (user {UserId}, dress {DressId}).",
                userId, dressId);
            return;
        }

        if (interactionType is InteractionType.TryOnReserved or InteractionType.RentalReserved &&
            !string.IsNullOrWhiteSpace(metadataJson) &&
            await HasReservationInteractionAsync(userId, dressId, interactionType, metadataJson, cancellationToken))
        {
            _logger.LogDebug(
                "Preskočena dupla rezervaciona interakcija {Type} (user {UserId}, dress {DressId}).",
                interactionType, userId, dressId);
            return;
        }

        var now = DateTime.UtcNow;
        var resolvedWeight = weight ?? ResolveWeight(interactionType);

        _context.UserDressInteractions.Add(new UserDressInteraction
        {
            UserId = userId,
            DressId = dressId,
            InteractionType = interactionType,
            Weight = resolvedWeight,
            OccurredAtUtc = now,
            SessionId = sessionId?.Trim(),
            Source = source,
            MetadataJson = metadataJson,
            CreatedAtUtc = now,
            IsDeleted = false
        });

        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task RemoveFavoriteAsync(
        int userId,
        int dressId,
        CancellationToken cancellationToken = default)
    {
        var favorite = await _context.UserDressInteractions
            .FirstOrDefaultAsync(
                i => !i.IsDeleted
                     && i.UserId == userId
                     && i.DressId == dressId
                     && i.InteractionType == InteractionType.Favorite,
                cancellationToken);

        if (favorite == null)
            return;

        var now = DateTime.UtcNow;
        favorite.IsDeleted = true;
        favorite.UpdatedAtUtc = now;

        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<int>> GetFavoriteDressIdsAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return await _context.UserDressInteractions
            .AsNoTracking()
            .Where(i => !i.IsDeleted
                        && i.UserId == userId
                        && i.InteractionType == InteractionType.Favorite)
            .Select(i => i.DressId)
            .Distinct()
            .ToListAsync(cancellationToken);
    }

    internal static string BuildReservationMetadata(string reservationKey, int reservationId)
        => JsonSerializer.Serialize(new Dictionary<string, int> { [reservationKey] = reservationId });

    private async Task ValidateDressAsync(int dressId, CancellationToken cancellationToken)
    {
        var dressExists = await _context.Dresses
            .AsNoTracking()
            .AnyAsync(
                d => d.Id == dressId && !d.IsDeleted && d.Status == DressStatus.Active,
                cancellationToken);

        if (!dressExists)
            throw new UserException("Vjenčanica nije pronađena ili nije dostupna.");
    }

    private async Task<bool> IsDuplicateViewAsync(
        int userId,
        int dressId,
        string? sessionId,
        CancellationToken cancellationToken)
    {
        var cutoff = DateTime.UtcNow.AddMinutes(-_options.Value.ViewDeduplicationMinutes);

        var query = _context.UserDressInteractions
            .AsNoTracking()
            .Where(i => !i.IsDeleted
                        && i.UserId == userId
                        && i.DressId == dressId
                        && i.InteractionType == InteractionType.View
                        && i.OccurredAtUtc >= cutoff);

        if (!string.IsNullOrWhiteSpace(sessionId))
            query = query.Where(i => i.SessionId == sessionId.Trim());

        return await query.AnyAsync(cancellationToken);
    }

    private async Task<bool> HasActiveFavoriteAsync(
        int userId,
        int dressId,
        CancellationToken cancellationToken)
    {
        return await _context.UserDressInteractions
            .AsNoTracking()
            .AnyAsync(
                i => !i.IsDeleted
                     && i.UserId == userId
                     && i.DressId == dressId
                     && i.InteractionType == InteractionType.Favorite,
                cancellationToken);
    }

    private async Task<bool> HasReservationInteractionAsync(
        int userId,
        int dressId,
        InteractionType interactionType,
        string metadataJson,
        CancellationToken cancellationToken)
    {
        return await _context.UserDressInteractions
            .AsNoTracking()
            .AnyAsync(
                i => !i.IsDeleted
                     && i.UserId == userId
                     && i.DressId == dressId
                     && i.InteractionType == interactionType
                     && i.MetadataJson == metadataJson,
                cancellationToken);
    }

    private decimal ResolveWeight(InteractionType interactionType)
    {
        var weights = _options.Value.InteractionWeights;

        return interactionType switch
        {
            InteractionType.View => weights.View,
            InteractionType.Favorite => weights.Favorite,
            InteractionType.TryOnReserved => weights.TryOnReserved,
            InteractionType.RentalReserved => weights.RentalReserved,
            InteractionType.ReviewSubmitted => weights.ReviewSubmitted,
            _ => throw new UserException($"Tip interakcije '{interactionType}' nije podržan za zapis.")
        };
    }
}
