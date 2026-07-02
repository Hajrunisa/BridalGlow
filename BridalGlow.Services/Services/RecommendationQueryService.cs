using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Responses;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace BridalGlow.Services.Services;

public class RecommendationQueryService : IRecommendationQueryService
{
    private readonly BridalGlowDbContext _context;
    private readonly IOptions<RecommenderOptions> _options;

    public RecommendationQueryService(
        BridalGlowDbContext context,
        IOptions<RecommenderOptions> options)
    {
        _context = context;
        _options = options;
    }

    public async Task<IReadOnlyList<RecommendationItemResponse>> GetForUserAsync(
        int userId,
        int? limit = null,
        CancellationToken cancellationToken = default)
    {
        var effectiveLimit = ResolveLimit(limit, _options.Value.TopKRecommendations);

        var latestModelVersion = await GetLatestSnapshotModelVersionForUserAsync(userId, cancellationToken);
        if (latestModelVersion == null)
            return await GetColdStartAsync(effectiveLimit, cancellationToken);

        var snapshots = await _context.RecommendationSnapshots
            .AsNoTracking()
            .Where(s => s.UserId == userId && s.ModelVersion == latestModelVersion)
            .OrderBy(s => s.Rank)
            .Take(effectiveLimit)
            .ToListAsync(cancellationToken);

        if (snapshots.Count == 0)
            return await GetColdStartAsync(effectiveLimit, cancellationToken);

        var dressIds = snapshots.Select(s => s.DressId).Distinct().ToList();
        var dresses = await LoadActiveDressListItemsAsync(dressIds, cancellationToken);
        var dressMap = dresses.ToDictionary(d => d.Id);

        var userInteractions = await LoadUserInteractionContextAsync(userId, cancellationToken);
        var similarities = await LoadSimilarityLookupAsync(latestModelVersion, cancellationToken);

        var results = new List<RecommendationItemResponse>();

        foreach (var snapshot in snapshots)
        {
            if (!dressMap.TryGetValue(snapshot.DressId, out var dressEntity))
                continue;

            results.Add(new RecommendationItemResponse
            {
                Dress = DressListItemMapper.Map(dressEntity),
                Score = snapshot.Score,
                Rank = snapshot.Rank,
                Reason = BuildPersonalizedReason(
                    snapshot.DressId,
                    userInteractions,
                    similarities,
                    dressMap)
            });
        }

        return results;
    }

    public async Task<IReadOnlyList<SimilarDressResponse>> GetSimilarDressesAsync(
        int dressId,
        int? limit = null,
        CancellationToken cancellationToken = default)
    {
        var effectiveLimit = ResolveLimit(limit, _options.Value.TopKSimilarDresses);

        await EnsureActiveDressExistsAsync(dressId, cancellationToken);

        var modelVersion = await GetLatestSimilarityModelVersionAsync(cancellationToken);
        if (modelVersion == null)
            return Array.Empty<SimilarDressResponse>();

        var similarRows = await _context.DressSimilarities
            .AsNoTracking()
            .Where(s => s.DressId == dressId && s.ModelVersion == modelVersion)
            .OrderByDescending(s => s.Score)
            .Take(effectiveLimit)
            .ToListAsync(cancellationToken);

        if (similarRows.Count == 0)
            return Array.Empty<SimilarDressResponse>();

        var dressIds = similarRows.Select(s => s.SimilarDressId).Distinct().ToList();
        var dresses = await LoadActiveDressListItemsAsync(dressIds, cancellationToken);
        var dressMap = dresses.ToDictionary(d => d.Id);

        return similarRows
            .Where(row => dressMap.ContainsKey(row.SimilarDressId))
            .Select(row => new SimilarDressResponse
            {
                Dress = DressListItemMapper.Map(dressMap[row.SimilarDressId]),
                Score = row.Score,
                Reason = "Slična haljina prema ponašanju korisnica u našoj kolekciji."
            })
            .ToList();
    }

    public async Task<IReadOnlyList<RecommendationItemResponse>> GetColdStartAsync(
        int? limit = null,
        CancellationToken cancellationToken = default)
    {
        var effectiveLimit = ResolveLimit(limit, _options.Value.TopKRecommendations);

        var interactionCounts = await _context.UserDressInteractions
            .AsNoTracking()
            .Where(i => !i.IsDeleted)
            .GroupBy(i => i.DressId)
            .Select(g => new { DressId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.DressId, x => x.Count, cancellationToken);

        var dresses = await _context.Dresses
            .AsNoTracking()
            .Where(d => !d.IsDeleted && d.Status == DressStatus.Active)
            .Include(d => d.PrimaryCategory)
            .Include(d => d.Images.Where(i => i.IsPrimary && !i.IsDeleted))
            .Include(d => d.TagMaps.Where(m => !m.IsDeleted))
                .ThenInclude(m => m.DressTag)
            .ToListAsync(cancellationToken);

        var ranked = dresses
            .Select(d => new
            {
                Dress = d,
                Score = ComputeColdStartScore(d, interactionCounts.GetValueOrDefault(d.Id))
            })
            .OrderByDescending(x => x.Score)
            .ThenByDescending(x => x.Dress.AverageRating)
            .ThenBy(x => x.Dress.Name)
            .Take(effectiveLimit)
            .ToList();

        var rank = 1;
        return ranked
            .Select(x => new RecommendationItemResponse
            {
                Dress = DressListItemMapper.Map(x.Dress),
                Score = RoundScore(x.Score),
                Rank = rank++,
                Reason = BuildColdStartReason(x.Dress, interactionCounts.GetValueOrDefault(x.Dress.Id))
            })
            .ToList();
    }

    public async Task<RecommenderStatusResponse> GetStatusAsync(
        CancellationToken cancellationToken = default)
    {
        var similarityMeta = await _context.DressSimilarities
            .AsNoTracking()
            .GroupBy(_ => 1)
            .Select(g => new
            {
                Count = g.Count(),
                LastRun = g.Max(x => x.CalculatedAtUtc),
                ModelVersion = g.OrderByDescending(x => x.CalculatedAtUtc).Select(x => x.ModelVersion).FirstOrDefault()
            })
            .FirstOrDefaultAsync(cancellationToken);

        var snapshotMeta = await _context.RecommendationSnapshots
            .AsNoTracking()
            .GroupBy(_ => 1)
            .Select(g => new
            {
                Count = g.Count(),
                LastRun = g.Max(x => x.GeneratedAtUtc)
            })
            .FirstOrDefaultAsync(cancellationToken);

        var interactionCount = await _context.UserDressInteractions
            .AsNoTracking()
            .CountAsync(i => !i.IsDeleted, cancellationToken);

        return new RecommenderStatusResponse
        {
            ModelVersion = similarityMeta?.ModelVersion ?? string.Empty,
            LastSimilarityRunAtUtc = similarityMeta?.LastRun,
            LastSnapshotRunAtUtc = snapshotMeta?.LastRun,
            InteractionCount = interactionCount,
            SimilarityPairCount = similarityMeta?.Count ?? 0,
            SnapshotCount = snapshotMeta?.Count ?? 0
        };
    }

    public async Task<RecommenderTrendsResponse> GetTrendsAsync(
        int? limit = null,
        CancellationToken cancellationToken = default)
    {
        var effectiveLimit = ResolveLimit(limit, _options.Value.TopKRecommendations);

        var modelVersion = await GetLatestSnapshotModelVersionAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(modelVersion))
        {
            return new RecommenderTrendsResponse();
        }

        var lastSnapshotRunAtUtc = await _context.RecommendationSnapshots
            .AsNoTracking()
            .Where(s => s.ModelVersion == modelVersion)
            .MaxAsync(s => (DateTime?)s.GeneratedAtUtc, cancellationToken);

        var aggregates = await _context.RecommendationSnapshots
            .AsNoTracking()
            .Where(s => s.ModelVersion == modelVersion)
            .GroupBy(s => s.DressId)
            .Select(g => new
            {
                DressId = g.Key,
                AppearanceCount = g.Count(),
                TotalScore = g.Sum(x => x.Score)
            })
            .OrderByDescending(x => x.TotalScore)
            .ThenByDescending(x => x.AppearanceCount)
            .Take(effectiveLimit)
            .ToListAsync(cancellationToken);

        if (aggregates.Count == 0)
        {
            return new RecommenderTrendsResponse
            {
                ModelVersion = modelVersion,
                LastSnapshotRunAtUtc = lastSnapshotRunAtUtc
            };
        }

        var dressIds = aggregates.Select(a => a.DressId).ToList();
        var dresses = await LoadActiveDressListItemsAsync(dressIds, cancellationToken);
        var dressMap = dresses.ToDictionary(d => d.Id);

        var rank = 1;
        var items = new List<RecommendationTrendItemResponse>();

        foreach (var aggregate in aggregates)
        {
            if (!dressMap.TryGetValue(aggregate.DressId, out var dressEntity))
                continue;

            items.Add(new RecommendationTrendItemResponse
            {
                Dress = DressListItemMapper.Map(dressEntity),
                AppearanceCount = aggregate.AppearanceCount,
                TotalScore = RoundScore(aggregate.TotalScore),
                Rank = rank++
            });
        }

        return new RecommenderTrendsResponse
        {
            ModelVersion = modelVersion,
            LastSnapshotRunAtUtc = lastSnapshotRunAtUtc,
            Items = items
        };
    }

    private async Task<string?> GetLatestSnapshotModelVersionAsync(
        CancellationToken cancellationToken)
    {
        return await _context.RecommendationSnapshots
            .AsNoTracking()
            .OrderByDescending(s => s.GeneratedAtUtc)
            .Select(s => s.ModelVersion)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<string?> GetLatestSnapshotModelVersionForUserAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        return await _context.RecommendationSnapshots
            .AsNoTracking()
            .Where(s => s.UserId == userId)
            .OrderByDescending(s => s.GeneratedAtUtc)
            .Select(s => s.ModelVersion)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<string?> GetLatestSimilarityModelVersionAsync(CancellationToken cancellationToken)
    {
        return await _context.DressSimilarities
            .AsNoTracking()
            .OrderByDescending(s => s.CalculatedAtUtc)
            .Select(s => s.ModelVersion)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<List<Dress>> LoadActiveDressListItemsAsync(
        IReadOnlyCollection<int> dressIds,
        CancellationToken cancellationToken)
    {
        if (dressIds.Count == 0)
            return new List<Dress>();

        return await _context.Dresses
            .AsNoTracking()
            .Where(d => dressIds.Contains(d.Id) && !d.IsDeleted && d.Status == DressStatus.Active)
            .Include(d => d.PrimaryCategory)
            .Include(d => d.Images.Where(i => i.IsPrimary && !i.IsDeleted))
            .Include(d => d.TagMaps.Where(m => !m.IsDeleted))
                .ThenInclude(m => m.DressTag)
            .ToListAsync(cancellationToken);
    }

    private async Task EnsureActiveDressExistsAsync(int dressId, CancellationToken cancellationToken)
    {
        var exists = await _context.Dresses
            .AsNoTracking()
            .AnyAsync(d => d.Id == dressId && !d.IsDeleted && d.Status == DressStatus.Active, cancellationToken);

        if (!exists)
            throw new UserException("Vjenčanica nije pronađena ili nije dostupna.");
    }

    private async Task<List<UserInteractionContext>> LoadUserInteractionContextAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        return await _context.UserDressInteractions
            .AsNoTracking()
            .Where(i => !i.IsDeleted && i.UserId == userId)
            .GroupBy(i => new { i.DressId, i.InteractionType })
            .Select(g => new UserInteractionContext
            {
                DressId = g.Key.DressId,
                InteractionType = g.Key.InteractionType,
                TotalWeight = g.Sum(x => x.Weight)
            })
            .ToListAsync(cancellationToken);
    }

    private async Task<Dictionary<(int SourceDressId, int SimilarDressId), decimal>> LoadSimilarityLookupAsync(
        string modelVersion,
        CancellationToken cancellationToken)
    {
        var rows = await _context.DressSimilarities
            .AsNoTracking()
            .Where(s => s.ModelVersion == modelVersion)
            .Select(s => new { s.DressId, s.SimilarDressId, s.Score })
            .ToListAsync(cancellationToken);

        return rows.ToDictionary(
            r => (r.DressId, r.SimilarDressId),
            r => r.Score);
    }

    private string BuildPersonalizedReason(
        int recommendedDressId,
        IReadOnlyList<UserInteractionContext> userInteractions,
        IReadOnlyDictionary<(int SourceDressId, int SimilarDressId), decimal> similarities,
        IReadOnlyDictionary<int, Dress> dressMap)
    {
        var bestContribution = 0m;
        UserInteractionContext? bestInteraction = null;

        foreach (var interaction in userInteractions)
        {
            if (!similarities.TryGetValue((interaction.DressId, recommendedDressId), out var similarityScore))
                continue;

            var contribution = similarityScore * interaction.TotalWeight;
            if (contribution > bestContribution)
            {
                bestContribution = contribution;
                bestInteraction = interaction;
            }
        }

        if (bestInteraction == null || !dressMap.TryGetValue(bestInteraction.DressId, out var sourceDress))
            return "Preporučeno na osnovu vaših prethodnih interakcija u katalogu.";

        return $"Slično haljini '{sourceDress.Name}' koju ste {DescribeInteraction(bestInteraction.InteractionType)}.";
    }

    private static string BuildColdStartReason(Dress dress, int interactionCount)
    {
        if (dress.IsFeatured && dress.AverageRating >= 4.5m)
            return "Istaknuta kolekcija s visokom ocjenom korisnica.";

        if (dress.IsFeatured)
            return "Istaknuta kolekcija u našem salonu.";

        if (interactionCount >= 5)
            return "Popularno među korisnicama BridalGlow platforme.";

        if (dress.AverageRating >= 4.0m && dress.RatingCount > 0)
            return "Visoko ocijenjena haljina u našoj kolekciji.";

        return "Preporučeno za upoznavanje naše kolekcije.";
    }

    private static string DescribeInteraction(InteractionType interactionType) => interactionType switch
    {
        InteractionType.View => "pregledali",
        InteractionType.Favorite => "označili kao omiljenu",
        InteractionType.TryOnReserved => "rezervisali probu",
        InteractionType.RentalReserved => "rezervisali za iznajmljivanje",
        InteractionType.ReviewSubmitted => "ocijenili",
        _ => "interagovali s"
    };

    private static decimal ComputeColdStartScore(Dress dress, int interactionCount)
    {
        var featuredBoost = dress.IsFeatured ? 2m : 0m;
        var popularityBoost = Math.Min(interactionCount, 20) * 0.05m;
        return featuredBoost + dress.AverageRating + popularityBoost;
    }

    private static int ResolveLimit(int? limit, int configuredDefault)
    {
        var effective = limit ?? configuredDefault;
        return Math.Clamp(effective, 1, 100);
    }

    private static decimal RoundScore(decimal score)
        => Math.Round(score, 6, MidpointRounding.AwayFromZero);

    private sealed class UserInteractionContext
    {
        public int DressId { get; init; }
        public InteractionType InteractionType { get; init; }
        public decimal TotalWeight { get; init; }
    }
}
