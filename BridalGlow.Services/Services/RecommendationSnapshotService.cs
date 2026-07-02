using System.Diagnostics;
using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model.Enums;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BridalGlow.Services.Services;

public class RecommendationSnapshotService : IRecommendationSnapshotService
{
    private static readonly InteractionType[] StrongInteractionTypes =
    {
        InteractionType.RentalReserved,
        InteractionType.ReviewSubmitted
    };

    private readonly BridalGlowDbContext _context;
    private readonly IOptions<RecommenderOptions> _options;
    private readonly ILogger<RecommendationSnapshotService> _logger;

    public RecommendationSnapshotService(
        BridalGlowDbContext context,
        IOptions<RecommenderOptions> options,
        ILogger<RecommendationSnapshotService> logger)
    {
        _context = context;
        _options = options;
        _logger = logger;
    }

    public async Task<int> RecomputeSnapshotsAsync(CancellationToken cancellationToken = default)
    {
        var stopwatch = Stopwatch.StartNew();
        var options = _options.Value;
        var topK = options.TopKRecommendations;

        var modelVersion = await _context.DressSimilarities
            .AsNoTracking()
            .OrderByDescending(s => s.CalculatedAtUtc)
            .Select(s => s.ModelVersion)
            .FirstOrDefaultAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(modelVersion))
        {
            _logger.LogWarning("Snapshot recompute skipped: no dress similarity model version found.");
            return 0;
        }

        var similarities = await _context.DressSimilarities
            .AsNoTracking()
            .Where(s => s.ModelVersion == modelVersion)
            .Select(s => new { s.DressId, s.SimilarDressId, s.Score })
            .ToListAsync(cancellationToken);

        if (similarities.Count == 0)
        {
            _logger.LogWarning(
                "Snapshot recompute skipped: no similarity pairs for model version {ModelVersion}.",
                modelVersion);
            return 0;
        }

        var similarityNeighbors = BuildSimilarityNeighborLookup(
            similarities.Select(s => (s.DressId, s.SimilarDressId, s.Score)));

        var activeDressIds = await _context.Dresses
            .AsNoTracking()
            .Where(d => !d.IsDeleted && d.Status == DressStatus.Active)
            .Select(d => d.Id)
            .ToListAsync(cancellationToken);

        var activeDressSet = activeDressIds.ToHashSet();

        var interactions = await _context.UserDressInteractions
            .AsNoTracking()
            .Where(i => !i.IsDeleted && activeDressSet.Contains(i.DressId))
            .Select(i => new { i.UserId, i.DressId, i.InteractionType, i.Weight })
            .ToListAsync(cancellationToken);

        if (interactions.Count == 0)
        {
            _logger.LogWarning("Snapshot recompute skipped: no user dress interactions found.");
            return 0;
        }

        var interactionRows = interactions
            .Select(i => (i.UserId, i.DressId, i.InteractionType, i.Weight))
            .ToList();

        var userDressWeights = BuildUserDressWeights(interactionRows);
        var userStrongDressIds = BuildStrongInteractionDressIds(interactionRows);
        var generatedAtUtc = DateTime.UtcNow;
        var snapshots = new List<RecommendationSnapshot>();

        foreach (var (userId, dressWeights) in userDressWeights)
        {
            userStrongDressIds.TryGetValue(userId, out var strongDressIds);
            strongDressIds ??= new HashSet<int>();

            var candidateScores = new Dictionary<int, decimal>();

            foreach (var (sourceDressId, weight) in dressWeights)
            {
                AccumulateSimilarityCandidates(
                    sourceDressId,
                    weight,
                    similarityNeighbors,
                    activeDressSet,
                    strongDressIds,
                    candidateScores);
            }

            if (candidateScores.Count == 0)
                continue;

            var rank = 1;
            foreach (var candidate in candidateScores
                         .OrderByDescending(x => x.Value)
                         .Take(topK))
            {
                snapshots.Add(new RecommendationSnapshot
                {
                    UserId = userId,
                    DressId = candidate.Key,
                    Score = RoundScore(candidate.Value),
                    Rank = rank++,
                    ModelVersion = modelVersion,
                    GeneratedAtUtc = generatedAtUtc
                });
            }
        }

        if (snapshots.Count == 0)
        {
            _logger.LogWarning(
                "Snapshot recompute produced no recommendations for model version {ModelVersion}.",
                modelVersion);
            return 0;
        }

        await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);

        try
        {
            var replacedCount = await _context.RecommendationSnapshots
                .Where(s => s.ModelVersion == modelVersion)
                .ExecuteDeleteAsync(cancellationToken);

            _context.RecommendationSnapshots.AddRange(snapshots);
            await _context.SaveChangesAsync(cancellationToken);

            var deletedCount = await _context.RecommendationSnapshots
                .Where(s => s.ModelVersion != modelVersion)
                .ExecuteDeleteAsync(cancellationToken);

            await transaction.CommitAsync(cancellationToken);

            stopwatch.Stop();
            _logger.LogInformation(
                "Snapshot recompute completed. ModelVersion={ModelVersion}, Users={UserCount}, " +
                "Snapshots={SnapshotCount}, ReplacedSnapshots={ReplacedCount}, RemovedOldSnapshots={DeletedCount}, DurationMs={DurationMs}",
                modelVersion,
                userDressWeights.Count,
                snapshots.Count,
                replacedCount,
                deletedCount,
                stopwatch.ElapsedMilliseconds);

            return snapshots.Count;
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    private static Dictionary<int, Dictionary<int, decimal>> BuildSimilarityNeighborLookup(
        IEnumerable<(int DressId, int SimilarDressId, decimal Score)> similarities)
    {
        var lookup = new Dictionary<int, Dictionary<int, decimal>>();

        foreach (var (dressId, similarDressId, score) in similarities)
        {
            AddSimilarityNeighbor(lookup, dressId, similarDressId, score);
            AddSimilarityNeighbor(lookup, similarDressId, dressId, score);
        }

        return lookup;
    }

    private static void AddSimilarityNeighbor(
        Dictionary<int, Dictionary<int, decimal>> lookup,
        int sourceDressId,
        int relatedDressId,
        decimal score)
    {
        if (!lookup.TryGetValue(sourceDressId, out var neighbors))
        {
            neighbors = new Dictionary<int, decimal>();
            lookup[sourceDressId] = neighbors;
        }

        neighbors[relatedDressId] =
            Math.Max(neighbors.GetValueOrDefault(relatedDressId), score);
    }

    private static void AccumulateSimilarityCandidates(
        int sourceDressId,
        decimal weight,
        IReadOnlyDictionary<int, Dictionary<int, decimal>> similarityLookup,
        HashSet<int> activeDressSet,
        HashSet<int> strongDressIds,
        Dictionary<int, decimal> candidateScores)
    {
        if (!similarityLookup.TryGetValue(sourceDressId, out var relatedDresses))
            return;

        foreach (var (relatedDressId, score) in relatedDresses)
        {
            if (relatedDressId == sourceDressId)
                continue;

            if (!activeDressSet.Contains(relatedDressId))
                continue;

            if (strongDressIds.Contains(relatedDressId))
                continue;

            var contribution = score * weight;
            if (contribution <= 0)
                continue;

            candidateScores[relatedDressId] =
                candidateScores.GetValueOrDefault(relatedDressId) + contribution;
        }
    }

    private static Dictionary<int, Dictionary<int, decimal>> BuildUserDressWeights(
        IEnumerable<(int UserId, int DressId, InteractionType InteractionType, decimal Weight)> interactions)
    {
        var result = new Dictionary<int, Dictionary<int, decimal>>();

        foreach (var interaction in interactions)
        {
            if (!result.TryGetValue(interaction.UserId, out var dressWeights))
            {
                dressWeights = new Dictionary<int, decimal>();
                result[interaction.UserId] = dressWeights;
            }

            dressWeights[interaction.DressId] =
                dressWeights.GetValueOrDefault(interaction.DressId) + interaction.Weight;
        }

        return result;
    }

    private static Dictionary<int, HashSet<int>> BuildStrongInteractionDressIds(
        IEnumerable<(int UserId, int DressId, InteractionType InteractionType, decimal Weight)> interactions)
    {
        var result = new Dictionary<int, HashSet<int>>();

        foreach (var interaction in interactions)
        {
            if (!StrongInteractionTypes.Contains(interaction.InteractionType))
                continue;

            if (!result.TryGetValue(interaction.UserId, out var dressIds))
            {
                dressIds = new HashSet<int>();
                result[interaction.UserId] = dressIds;
            }

            dressIds.Add(interaction.DressId);
        }

        return result;
    }

    private static decimal RoundScore(decimal score)
        => Math.Round(score, 6, MidpointRounding.AwayFromZero);
}
