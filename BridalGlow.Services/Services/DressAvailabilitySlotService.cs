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

public class DressAvailabilitySlotService
    : BaseService<DressAvailabilitySlotResponse, DressAvailabilitySlotSearchObject, DressAvailabilitySlot>,
      IDressAvailabilitySlotService
{
    public DressAvailabilitySlotService(BridalGlowDbContext context, IMapper mapper)
        : base(context, mapper) { }

    // ── Read ─────────────────────────────────────────────────────────────────

    public override async Task<PagedResult<DressAvailabilitySlotResponse>> GetAsync(
        DressAvailabilitySlotSearchObject search)
    {
        NormalizePagination(search);

        var query = _context.DressAvailabilitySlots
            .Include(s => s.Dress)
            .Where(s => !s.IsDeleted)
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

        var list = await query.OrderBy(s => s.StartAtUtc).ToListAsync();
        return new PagedResult<DressAvailabilitySlotResponse>
        {
            Items = list.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    public override async Task<DressAvailabilitySlotResponse?> GetByIdAsync(int id)
    {
        var entity = await _context.DressAvailabilitySlots
            .Include(s => s.Dress)
            .FirstOrDefaultAsync(s => s.Id == id && !s.IsDeleted);

        return entity == null ? null : MapToResponse(entity);
    }

    // ── Create ────────────────────────────────────────────────────────────────

    public async Task<DressAvailabilitySlotResponse> CreateAsync(DressAvailabilitySlotCreateRequest request)
    {
        await ValidateCreateRequestAsync(request);

        var entity = new DressAvailabilitySlot
        {
            DressId = request.DressId,
            StartAtUtc = request.StartAtUtc,
            EndAtUtc = request.EndAtUtc,
            SlotType = request.SlotType,
            Reason = request.Reason?.Trim(),
            CreatedAtUtc = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.DressAvailabilitySlots.Add(entity);
        await _context.SaveChangesAsync();

        return (await GetByIdAsync(entity.Id))!;
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    public async Task<bool> DeleteAsync(int id)
    {
        var entity = await _context.DressAvailabilitySlots.FindAsync(id);
        if (entity == null || entity.IsDeleted)
            return false;

        // System-managed slots (TryOnHold / RentalHold) must not be deleted manually.
        if (entity.SlotType == AvailabilitySlotType.TryOnHold ||
            entity.SlotType == AvailabilitySlotType.RentalHold)
            throw new UserException("Ovaj slot je vezan za aktivnu rezervaciju i ne može se ručno obrisati.");

        entity.IsDeleted = true;
        entity.UpdatedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return true;
    }

    // ── Free slots ────────────────────────────────────────────────────────────

    /// <summary>
    /// Returns Available slots for <paramref name="dressId"/> on <paramref name="date"/>
    /// that are not fully overlapped by any blocking slot (Blocked / TryOnHold /
    /// RentalHold / MaintenanceBlock).
    /// </summary>
    public async Task<List<DressAvailabilitySlotResponse>> GetFreeSlotsAsync(int dressId, DateTime date)
    {
        var dayStart = NormalizeUtc(date.Date);
        var dayEnd = dayStart.AddDays(1);

        var slotsOnDay = await _context.DressAvailabilitySlots
            .Include(s => s.Dress)
            .Where(s => s.DressId == dressId
                     && !s.IsDeleted
                     && s.StartAtUtc < dayEnd
                     && s.EndAtUtc > dayStart)
            .ToListAsync();

        var available = slotsOnDay.Where(s => s.SlotType == AvailabilitySlotType.Available).ToList();
        var blocking = slotsOnDay.Where(s => s.SlotType != AvailabilitySlotType.Available).ToList();

        // A slot is free for the requested day if no blocking slot overlaps the
        // intersection of the Available slot with that specific day window.
        // This ensures that a RentalHold covering e.g. July 5–10 does NOT block
        // Try-On appointments on July 11–31 inside the same large Available slot.
        var freeSlots = available
            .Where(a =>
            {
                // Clip the Available slot to the queried day
                var effectiveStart = a.StartAtUtc < dayStart ? dayStart : a.StartAtUtc;
                var effectiveEnd   = a.EndAtUtc   > dayEnd   ? dayEnd   : a.EndAtUtc;

                return !blocking.Any(b =>
                    b.StartAtUtc < effectiveEnd &&
                    b.EndAtUtc   > effectiveStart);
            })
            .Select(MapToResponse)
            .OrderBy(s => s.StartAtUtc)
            .ToList();

        return freeSlots;
    }

    // ── Rental availability ───────────────────────────────────────────────────

    /// <summary>
    /// Returns all non-deleted availability slots (Available and blocking) for
    /// <paramref name="dressId"/> within the next 365 days.  The mobile rental
    /// booking screen uses this to highlight available periods and disable
    /// blocked dates in the date picker.
    /// </summary>
    public async Task<List<DressAvailabilitySlotResponse>> GetRentalAvailabilityAsync(int dressId)
    {
        var now = DateTime.UtcNow.Date;
        var horizon = now.AddDays(365);

        var slots = await _context.DressAvailabilitySlots
            .Include(s => s.Dress)
            .Where(s => s.DressId == dressId
                     && !s.IsDeleted
                     && s.EndAtUtc > now
                     && s.StartAtUtc < horizon)
            .OrderBy(s => s.StartAtUtc)
            .ToListAsync();

        return slots.Select(MapToResponse).ToList();
    }

    // ── Rental period validation ──────────────────────────────────────────────

    /// <inheritdoc />
    public async Task ValidateRentalPeriodAsync(int dressId, DateTime startUtc, DateTime endUtc)
    {
        startUtc = NormalizeUtc(startUtc);
        endUtc = NormalizeUtc(endUtc);

        // Each calendar day in [startDate, endDate) must overlap an Available slot.
        // Date-level checks (not exact timestamp containment) so that a rental sub-period
        // inside a large Available window (e.g. 01.07–31.07) is accepted even when the
        // slot has specific start/end times on the boundary days.
        for (var day = startUtc.Date; day < endUtc.Date; day = day.AddDays(1))
        {
            var dayStart = day;
            var dayEnd   = day.AddDays(1);

            var hasAvailable = await _context.DressAvailabilitySlots
                .AnyAsync(s => s.DressId == dressId
                            && !s.IsDeleted
                            && s.SlotType == AvailabilitySlotType.Available
                            && s.StartAtUtc < dayEnd
                            && s.EndAtUtc   > dayStart);

            if (!hasAvailable)
                throw new UserException(
                    "Odabrani period iznajmljivanja nije unutar dostupnog termina. " +
                    "Molimo odaberite termin koji je Staff/Admin označio kao dostupan za iznajmljivanje.");
        }

        var blockingTypes = new[]
        {
            AvailabilitySlotType.Blocked,
            AvailabilitySlotType.TryOnHold,
            AvailabilitySlotType.RentalHold,
            AvailabilitySlotType.MaintenanceBlock
        };

        var hasConflict = await _context.DressAvailabilitySlots
            .AnyAsync(s => s.DressId == dressId
                        && !s.IsDeleted
                        && blockingTypes.Contains(s.SlotType)
                        && s.StartAtUtc < endUtc
                        && s.EndAtUtc   > startUtc);

        if (hasConflict)
            throw new UserException(
                "Odabrani period je u konfliktu sa postojećom rezervacijom ili blokadom. " +
                "Molimo odaberite drugi termin.");
    }

    // ── Filter ────────────────────────────────────────────────────────────────

    protected override IQueryable<DressAvailabilitySlot> ApplyFilter(
        IQueryable<DressAvailabilitySlot> query, DressAvailabilitySlotSearchObject search)
    {
        if (search.DressId.HasValue)
            query = query.Where(s => s.DressId == search.DressId.Value);

        if (search.From.HasValue)
        {
            var fromUtc = NormalizeUtc(search.From.Value);
            query = query.Where(s => s.EndAtUtc >= fromUtc);
        }

        if (search.To.HasValue)
        {
            var toUtc = NormalizeUtc(search.To.Value);
            query = query.Where(s => s.StartAtUtc <= toUtc);
        }

        if (search.SlotType.HasValue)
            query = query.Where(s => s.SlotType == search.SlotType.Value);

        return query;
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    protected override DressAvailabilitySlotResponse MapToResponse(DressAvailabilitySlot entity) => new()
    {
        Id = entity.Id,
        DressId = entity.DressId,
        DressName = entity.Dress?.Name ?? string.Empty,
        DressCode = entity.Dress?.Code ?? string.Empty,
        StartAtUtc = entity.StartAtUtc,
        EndAtUtc = entity.EndAtUtc,
        SlotType = entity.SlotType,
        Reason = entity.Reason,
        SourceReservationId = entity.SourceReservationId,
        SourceReservationType = entity.SourceReservationType,
        CreatedAtUtc = entity.CreatedAtUtc,
        UpdatedAtUtc = entity.UpdatedAtUtc
    };

    // ── Validation ────────────────────────────────────────────────────────────

    private async Task ValidateCreateRequestAsync(DressAvailabilitySlotCreateRequest request)
    {
        request.StartAtUtc = NormalizeUtc(request.StartAtUtc);
        request.EndAtUtc = NormalizeUtc(request.EndAtUtc);

        if (request.StartAtUtc >= request.EndAtUtc)
            throw new UserException("Početak termina mora biti prije kraja termina.");

        var minDuration = TimeSpan.FromMinutes(30);
        if (request.EndAtUtc - request.StartAtUtc < minDuration)
            throw new UserException("Trajanje termina mora biti najmanje 30 minuta.");

        if (request.StartAtUtc < DateTime.UtcNow)
            throw new UserException("Ne možete dodati termin koji je u prošlosti.");

        var allowedTypes = new[] { AvailabilitySlotType.Available, AvailabilitySlotType.Blocked };
        if (!allowedTypes.Contains(request.SlotType))
            throw new UserException("Možete ručno kreirati samo Available ili Blocked slotove.");

        var dressExists = await _context.Dresses
            .AnyAsync(d => d.Id == request.DressId && !d.IsDeleted);
        if (!dressExists)
            throw new UserException("Odabrana vjenčanica ne postoji ili je obrisana.");

        // Prevent duplicate Available slots that overlap each other.
        if (request.SlotType == AvailabilitySlotType.Available)
        {
            var hasOverlap = await _context.DressAvailabilitySlots
                .AnyAsync(s => s.DressId == request.DressId
                            && !s.IsDeleted
                            && s.SlotType == AvailabilitySlotType.Available
                            && s.StartAtUtc < request.EndAtUtc
                            && s.EndAtUtc > request.StartAtUtc);

            if (hasOverlap)
                throw new UserException("Već postoji dostupni termin koji se preklapa s odabranim periodom.");
        }
    }

    /// <summary>
    /// API and PostgreSQL (legacy timestamp) store UTC wall-clock values.
    /// Unspecified values must not be converted via local timezone.
    /// </summary>
    private static DateTime NormalizeUtc(DateTime value)
        => value.Kind == DateTimeKind.Utc
            ? value
            : DateTime.SpecifyKind(value, DateTimeKind.Utc);
}
