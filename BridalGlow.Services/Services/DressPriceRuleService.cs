using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public class DressPriceRuleService
    : BaseService<DressPriceRuleResponse, DressPriceRuleSearchObject, DressPriceRule>,
      IDressPriceRuleService
{
    public DressPriceRuleService(BridalGlowDbContext context, IMapper mapper)
        : base(context, mapper) { }

    // ── Read ─────────────────────────────────────────────────────────────────

    public override async Task<PagedResult<DressPriceRuleResponse>> GetAsync(
        DressPriceRuleSearchObject search)
    {
        NormalizePagination(search);

        var query = _context.DressPriceRules
            .Include(r => r.Dress)
            .Where(r => !r.IsDeleted)
            .AsQueryable();

        query = ApplyFilter(query, search);

        int? totalCount = null;
        if (search.IncludeTotalCount)
            totalCount = await query.CountAsync();

        if (!search.RetrieveAll)
        {
            if (search.Page.HasValue && search.PageSize.HasValue)
                query = query.Skip(search.Page.Value * search.PageSize.Value);
            if (search.PageSize.HasValue)
                query = query.Take(search.PageSize.Value);
        }

        var list = await query.OrderByDescending(r => r.Priority).ThenBy(r => r.StartDateUtc).ToListAsync();
        return new PagedResult<DressPriceRuleResponse>
        {
            Items = list.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    public override async Task<DressPriceRuleResponse?> GetByIdAsync(int id)
    {
        var entity = await _context.DressPriceRules
            .Include(r => r.Dress)
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        return entity == null ? null : MapToResponse(entity);
    }

    // ── Create ────────────────────────────────────────────────────────────────

    public async Task<DressPriceRuleResponse> CreateAsync(DressPriceRuleCreateRequest request)
    {
        await ValidateCreateRequestAsync(request);

        var entity = new DressPriceRule
        {
            DressId = request.DressId,
            RuleType = request.RuleType,
            Amount = request.Amount,
            Percent = request.Percent,
            StartDateUtc = request.StartDateUtc,
            EndDateUtc = request.EndDateUtc,
            Priority = request.Priority,
            IsActive = request.IsActive,
            CreatedAtUtc = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.DressPriceRules.Add(entity);
        await _context.SaveChangesAsync();

        return (await GetByIdAsync(entity.Id))!;
    }

    // ── Update ────────────────────────────────────────────────────────────────

    public async Task<DressPriceRuleResponse?> UpdateAsync(int id, DressPriceRuleUpdateRequest request)
    {
        var entity = await _context.DressPriceRules.FindAsync(id);
        if (entity == null || entity.IsDeleted)
            return null;

        await ValidateUpdateRequestAsync(entity, request);

        entity.RuleType = request.RuleType;
        entity.Amount = request.Amount;
        entity.Percent = request.Percent;
        entity.StartDateUtc = request.StartDateUtc;
        entity.EndDateUtc = request.EndDateUtc;
        entity.Priority = request.Priority;
        entity.IsActive = request.IsActive;
        entity.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return await GetByIdAsync(id);
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    public async Task<bool> DeleteAsync(int id)
    {
        var entity = await _context.DressPriceRules.FindAsync(id);
        if (entity == null || entity.IsDeleted)
            return false;

        entity.IsDeleted = true;
        entity.UpdatedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return true;
    }

    // ── Effective Price ───────────────────────────────────────────────────────

    /// <summary>
    /// Returns the effective price for a dress in the given period.
    /// The highest-priority active rule that overlaps the period is applied.
    /// If no rule applies, Dress.BaseRentalPrice is used.
    /// </summary>
    public async Task<EffectivePriceResponse> GetEffectivePriceAsync(
        int dressId, DateTime startAt, DateTime endAt)
    {
        var dress = await _context.Dresses
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.Id == dressId && !d.IsDeleted);

        if (dress == null)
            throw new UserException("Odabrana vjenčanica ne postoji ili je obrisana.");

        var startUtc = startAt.Kind == DateTimeKind.Utc ? startAt : startAt.ToUniversalTime();
        var endUtc = endAt.Kind == DateTimeKind.Utc ? endAt : endAt.ToUniversalTime();

        var rules = await _context.DressPriceRules
            .Include(r => r.Dress)
            .Where(r => r.DressId == dressId
                     && !r.IsDeleted
                     && r.IsActive
                     && r.StartDateUtc <= endUtc
                     && (r.EndDateUtc == null || r.EndDateUtc >= startUtc))
            .OrderByDescending(r => r.Priority)
            .ToListAsync();

        DressPriceRule? appliedRule = null;
        decimal effectivePrice = dress.BaseRentalPrice;

        if (rules.Count > 0)
        {
            appliedRule = SelectBestRule(rules, startUtc, endUtc);
            if (appliedRule != null)
                effectivePrice = CalculatePrice(dress.BaseRentalPrice, appliedRule);
        }

        return new EffectivePriceResponse
        {
            DressId = dressId,
            StartAt = startUtc,
            EndAt = endUtc,
            BaseRentalPrice = dress.BaseRentalPrice,
            EffectivePrice = effectivePrice,
            AppliedRule = appliedRule != null ? MapToResponse(appliedRule) : null
        };
    }

    // ── Pricing logic ─────────────────────────────────────────────────────────

    /// <summary>
    /// Selects the single best rule to apply for the given period.
    /// Rules are pre-sorted descending by priority; the first applicable wins.
    /// Weekend rules additionally require at least one weekend day in the period.
    /// </summary>
    private static DressPriceRule? SelectBestRule(
        IEnumerable<DressPriceRule> rules, DateTime startUtc, DateTime endUtc)
    {
        foreach (var rule in rules)
        {
            if (rule.RuleType == PriceRuleType.Weekend && !PeriodContainsWeekend(startUtc, endUtc))
                continue;

            return rule;
        }
        return null;
    }

    /// <summary>
    /// Checks whether the given UTC period contains at least one Saturday or Sunday.
    /// </summary>
    private static bool PeriodContainsWeekend(DateTime startUtc, DateTime endUtc)
    {
        for (var d = startUtc.Date; d <= endUtc.Date; d = d.AddDays(1))
        {
            if (d.DayOfWeek == DayOfWeek.Saturday || d.DayOfWeek == DayOfWeek.Sunday)
                return true;
        }
        return false;
    }

    /// <summary>
    /// Applies a rule to a base price.
    /// If Percent is set: price = basePrice * (1 - Percent/100).
    /// Otherwise: the rule's Amount is the flat effective price.
    /// </summary>
    private static decimal CalculatePrice(decimal basePrice, DressPriceRule rule)
    {
        if (rule.Percent.HasValue)
            return Math.Round(basePrice * (1m - rule.Percent.Value / 100m), 2);

        return rule.Amount;
    }

    // ── Filter ────────────────────────────────────────────────────────────────

    protected override IQueryable<DressPriceRule> ApplyFilter(
        IQueryable<DressPriceRule> query, DressPriceRuleSearchObject search)
    {
        if (search.DressId.HasValue)
            query = query.Where(r => r.DressId == search.DressId.Value);

        if (search.RuleType.HasValue)
            query = query.Where(r => r.RuleType == search.RuleType.Value);

        if (search.IsActive.HasValue)
            query = query.Where(r => r.IsActive == search.IsActive.Value);

        return query;
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    protected override DressPriceRuleResponse MapToResponse(DressPriceRule entity) => new()
    {
        Id = entity.Id,
        DressId = entity.DressId,
        DressName = entity.Dress?.Name ?? string.Empty,
        DressCode = entity.Dress?.Code ?? string.Empty,
        RuleType = entity.RuleType,
        RuleTypeLabel = entity.RuleType.ToString(),
        Amount = entity.Amount,
        Percent = entity.Percent,
        StartDateUtc = entity.StartDateUtc,
        EndDateUtc = entity.EndDateUtc,
        Priority = entity.Priority,
        IsActive = entity.IsActive,
        CreatedAtUtc = entity.CreatedAtUtc,
        UpdatedAtUtc = entity.UpdatedAtUtc
    };

    // ── Validation ────────────────────────────────────────────────────────────

    private async Task ValidateCreateRequestAsync(DressPriceRuleCreateRequest request)
    {
        var dressExists = await _context.Dresses
            .AnyAsync(d => d.Id == request.DressId && !d.IsDeleted);
        if (!dressExists)
            throw new UserException("Odabrana vjenčanica ne postoji ili je obrisana.");

        ValidateDateRange(request.StartDateUtc, request.EndDateUtc);
        ValidateAmountOrPercent(request.Amount, request.Percent);
    }

    private Task ValidateUpdateRequestAsync(DressPriceRule entity, DressPriceRuleUpdateRequest request)
    {
        ValidateDateRange(request.StartDateUtc, request.EndDateUtc);
        ValidateAmountOrPercent(request.Amount, request.Percent);
        return Task.CompletedTask;
    }

    private static void ValidateDateRange(DateTime start, DateTime? end)
    {
        if (end.HasValue && end.Value <= start)
            throw new UserException("Datum završetka mora biti nakon datuma početka.");
    }

    private static void ValidateAmountOrPercent(decimal amount, decimal? percent)
    {
        if (percent.HasValue && amount != 0)
            throw new UserException("Možete unijeti ili iznos (Amount) ili procenat (Percent), ne oboje. Postavite Amount na 0 kada koristite Percent.");
    }
}
