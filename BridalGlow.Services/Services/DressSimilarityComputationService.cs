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

public class DressSimilarityComputationService : IDressSimilarityComputationService
{
    private readonly BridalGlowDbContext _context;
    private readonly IOptions<RecommenderOptions> _options;
    private readonly ILogger<DressSimilarityComputationService> _logger;

    public DressSimilarityComputationService(
        BridalGlowDbContext context,
        IOptions<RecommenderOptions> options,
        ILogger<DressSimilarityComputationService> logger)
    {
        _context = context;
        _options = options;
        _logger = logger;
    }

    public async Task<int> RecomputeSimilaritiesAsync(CancellationToken cancellationToken = default)
    {
        var stopwatch = Stopwatch.StartNew();
        var options = _options.Value;

        var activeDressIds = await _context.Dresses
            .AsNoTracking()
            .Where(d => !d.IsDeleted && d.Status == DressStatus.Active)
            .Select(d => d.Id)
            .ToListAsync(cancellationToken);

        if (activeDressIds.Count < 2)
        {
            _logger.LogWarning(
                "Similarity recompute skipped: fewer than two active dresses ({Count}).",
                activeDressIds.Count);
            return 0;
        }

        var activeDressSet = activeDressIds.ToHashSet();

        var interactions = await _context.UserDressInteractions
            .AsNoTracking()
            .Where(i => !i.IsDeleted && activeDressSet.Contains(i.DressId))
            .Select(i => new { i.UserId, i.DressId, i.Weight })
            .ToListAsync(cancellationToken);

        if (interactions.Count == 0)
        {
            _logger.LogWarning("Similarity recompute skipped: no user dress interactions found.");
            return 0;
        }

        var dressUserWeights = BuildDressUserWeightMatrix(
            interactions.Select(i => (i.UserId, i.DressId, i.Weight)));
        var dressNorms = ComputeDressNorms(dressUserWeights);

        var modelVersion = $"{options.ModelVersion}-{DateTime.UtcNow:yyyyMMdd-HHmmss}";
        var calculatedAtUtc = DateTime.UtcNow;
        var minScore = (double)options.MinSimilarityScore;
        var topK = options.TopKSimilarDresses;

        var newSimilarities = ComputeTopSimilarities(
            activeDressIds,
            dressUserWeights,
            dressNorms,
            modelVersion,
            calculatedAtUtc,
            minScore,
            topK);

        if (newSimilarities.Count == 0)
        {
            _logger.LogWarning(
                "Similarity recompute produced no pairs above minimum score {MinScore}.",
                minScore);
            return 0;
        }

        await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);

        try
        {
            _context.DressSimilarities.AddRange(newSimilarities);
            await _context.SaveChangesAsync(cancellationToken);

            var deletedCount = await _context.DressSimilarities
                .Where(s => s.ModelVersion != modelVersion)
                .ExecuteDeleteAsync(cancellationToken);

            await transaction.CommitAsync(cancellationToken);

            stopwatch.Stop();
            _logger.LogInformation(
                "Similarity recompute completed. ModelVersion={ModelVersion}, ActiveDresses={DressCount}, " +
                "Interactions={InteractionCount}, NewPairs={PairCount}, RemovedOldPairs={DeletedCount}, DurationMs={DurationMs}",
                modelVersion,
                activeDressIds.Count,
                interactions.Count,
                newSimilarities.Count,
                deletedCount,
                stopwatch.ElapsedMilliseconds);

            return newSimilarities.Count;
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    private static Dictionary<int, Dictionary<int, decimal>> BuildDressUserWeightMatrix(
        IEnumerable<(int UserId, int DressId, decimal Weight)> interactions)
    {
        var userDressWeights = new Dictionary<int, Dictionary<int, decimal>>();

        foreach (var interaction in interactions)
        {
            if (!userDressWeights.TryGetValue(interaction.UserId, out var dressWeights))
            {
                dressWeights = new Dictionary<int, decimal>();
                userDressWeights[interaction.UserId] = dressWeights;
            }

            dressWeights[interaction.DressId] =
                dressWeights.GetValueOrDefault(interaction.DressId) + interaction.Weight;
        }

        var dressUserWeights = new Dictionary<int, Dictionary<int, decimal>>();

        foreach (var (userId, dressWeights) in userDressWeights)
        {
            foreach (var (dressId, weight) in dressWeights)
            {
                if (!dressUserWeights.TryGetValue(dressId, out var userWeights))
                {
                    userWeights = new Dictionary<int, decimal>();
                    dressUserWeights[dressId] = userWeights;
                }

                userWeights[userId] = weight;
            }
        }

        return dressUserWeights;
    }

    private static Dictionary<int, double> ComputeDressNorms(
        Dictionary<int, Dictionary<int, decimal>> dressUserWeights)
    {
        var norms = new Dictionary<int, double>(dressUserWeights.Count);

        foreach (var (dressId, userWeights) in dressUserWeights)
        {
            double sumSquares = 0;
            foreach (var weight in userWeights.Values)
                sumSquares += (double)weight * (double)weight;

            norms[dressId] = Math.Sqrt(sumSquares);
        }

        return norms;
    }

    private static List<DressSimilarity> ComputeTopSimilarities(
        IReadOnlyList<int> activeDressIds,
        Dictionary<int, Dictionary<int, decimal>> dressUserWeights,
        Dictionary<int, double> dressNorms,
        string modelVersion,
        DateTime calculatedAtUtc,
        double minScore,
        int topK)
    {
        var results = new List<DressSimilarity>();

        foreach (var dressId in activeDressIds)
        {
            if (!dressUserWeights.TryGetValue(dressId, out var usersForDress))
                continue;

            if (!dressNorms.TryGetValue(dressId, out var normI) || normI == 0)
                continue;

            var candidateScores = new List<(int SimilarDressId, decimal Score)>();

            foreach (var otherDressId in activeDressIds)
            {
                if (otherDressId == dressId)
                    continue;

                if (!dressUserWeights.TryGetValue(otherDressId, out var usersForOther))
                    continue;

                if (!dressNorms.TryGetValue(otherDressId, out var normJ) || normJ == 0)
                    continue;

                double dotProduct = 0;
                foreach (var (userId, weightI) in usersForDress)
                {
                    if (usersForOther.TryGetValue(userId, out var weightJ))
                        dotProduct += (double)weightI * (double)weightJ;
                }

                if (dotProduct <= 0)
                    continue;

                var score = dotProduct / (normI * normJ);
                if (score < minScore)
                    continue;

                candidateScores.Add((otherDressId, RoundScore(score)));
            }

            foreach (var candidate in candidateScores
                         .OrderByDescending(x => x.Score)
                         .Take(topK))
            {
                results.Add(new DressSimilarity
                {
                    DressId = dressId,
                    SimilarDressId = candidate.SimilarDressId,
                    Score = candidate.Score,
                    ModelVersion = modelVersion,
                    CalculatedAtUtc = calculatedAtUtc
                });
            }
        }

        return results;
    }

    private static decimal RoundScore(double score)
        => Math.Round((decimal)score, 6, MidpointRounding.AwayFromZero);
}
