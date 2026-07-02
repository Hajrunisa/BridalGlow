using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public class MaintenanceRecordService : IMaintenanceRecordService
{
    private readonly BridalGlowDbContext _context;

    public MaintenanceRecordService(BridalGlowDbContext context)
    {
        _context = context;
    }

    // ── Read ──────────────────────────────────────────────────────────────────

    public async Task<PagedResult<MaintenanceRecordResponse>> GetAsync(MaintenanceRecordSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery();
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

        var items = await query.OrderByDescending(m => m.CreatedAtUtc).ToListAsync();
        return new PagedResult<MaintenanceRecordResponse>
        {
            Items = items.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    public async Task<MaintenanceRecordResponse?> GetByIdAsync(int id)
    {
        var record = await BuildBaseQuery()
            .FirstOrDefaultAsync(m => m.Id == id);

        return record == null ? null : MapToResponse(record);
    }

    // ── Create ────────────────────────────────────────────────────────────────

    public async Task<MaintenanceRecordResponse> CreateAsync(int staffUserId, MaintenanceRecordCreateRequest request)
    {
        var dress = await _context.Dresses
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.Id == request.DressId && !d.IsDeleted);

        if (dress == null)
            throw new UserException("Vjenčanica nije pronađena.");

        if (string.IsNullOrWhiteSpace(request.Description))
            throw new UserException("Opis održavanja je obavezan.");

        if (request.OutOfServiceFromUtc.HasValue && request.OutOfServiceToUtc.HasValue
            && request.OutOfServiceToUtc.Value <= request.OutOfServiceFromUtc.Value)
            throw new UserException("Datum kraja van servisa mora biti nakon datuma početka.");

        var now = DateTime.UtcNow;

        var record = new MaintenanceRecord
        {
            DressId = request.DressId,
            RecordedByUserId = staffUserId,
            MaintenanceType = request.MaintenanceType,
            Status = MaintenanceStatus.Logged,
            Description = request.Description.Trim(),
            CostAmount = request.CostAmount,
            VendorName = request.VendorName?.Trim(),
            InvoiceNumber = request.InvoiceNumber?.Trim(),
            BeforeCondition = request.BeforeCondition,
            OutOfServiceFromUtc = NormalizeUtc(request.OutOfServiceFromUtc),
            OutOfServiceToUtc = NormalizeUtc(request.OutOfServiceToUtc),
            PerformedAtUtc = NormalizeUtc(request.PerformedAtUtc) ?? now,
            NextCheckAtUtc = NormalizeUtc(request.NextCheckAtUtc),
            CreatedAtUtc = now,
            IsDeleted = false
        };

        _context.MaintenanceRecords.Add(record);
        await _context.SaveChangesAsync();

        return await LoadAndMapAsync(record.Id);
    }

    // ── Update ────────────────────────────────────────────────────────────────

    public async Task<MaintenanceRecordResponse> UpdateAsync(int id, MaintenanceRecordUpdateRequest request)
    {
        var record = await GetRecordOrThrowAsync(id);

        if (record.Status == MaintenanceStatus.Completed || record.Status == MaintenanceStatus.Cancelled)
            throw new UserException($"Zapis sa statusom '{record.Status}' ne može biti izmijenjen.");

        if (request.OutOfServiceFromUtc.HasValue && request.OutOfServiceToUtc.HasValue
            && request.OutOfServiceToUtc.Value <= request.OutOfServiceFromUtc.Value)
            throw new UserException("Datum kraja van servisa mora biti nakon datuma početka.");

        if (request.MaintenanceType.HasValue)
            record.MaintenanceType = request.MaintenanceType.Value;

        if (!string.IsNullOrWhiteSpace(request.Description))
            record.Description = request.Description.Trim();

        if (request.CostAmount.HasValue)
            record.CostAmount = request.CostAmount.Value;

        if (request.VendorName != null)
            record.VendorName = request.VendorName.Trim();

        if (request.InvoiceNumber != null)
            record.InvoiceNumber = request.InvoiceNumber.Trim();

        if (request.BeforeCondition.HasValue)
            record.BeforeCondition = request.BeforeCondition;

        if (request.AfterCondition.HasValue)
            record.AfterCondition = request.AfterCondition;

        if (request.OutOfServiceFromUtc.HasValue)
            record.OutOfServiceFromUtc = NormalizeUtc(request.OutOfServiceFromUtc);

        if (request.OutOfServiceToUtc.HasValue)
            record.OutOfServiceToUtc = NormalizeUtc(request.OutOfServiceToUtc);

        if (request.PerformedAtUtc.HasValue)
            record.PerformedAtUtc = NormalizeUtc(request.PerformedAtUtc)!.Value;

        if (request.NextCheckAtUtc.HasValue)
            record.NextCheckAtUtc = NormalizeUtc(request.NextCheckAtUtc);

        record.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return await LoadAndMapAsync(record.Id);
    }

    // ── Soft delete ───────────────────────────────────────────────────────────

    public async Task<bool> DeleteAsync(int id)
    {
        var record = await _context.MaintenanceRecords
            .FirstOrDefaultAsync(m => m.Id == id && !m.IsDeleted);

        if (record == null)
            return false;

        if (record.Status == MaintenanceStatus.InProgress)
            throw new UserException("Zapis u toku (InProgress) ne može biti obrisan. Otkazite ga prvo.");

        record.IsDeleted = true;
        record.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    // ── Status transitions ────────────────────────────────────────────────────

    public async Task<MaintenanceRecordResponse> StartAsync(int id)
    {
        var record = await GetRecordOrThrowAsync(id);

        if (record.Status != MaintenanceStatus.Logged)
            throw new UserException($"Samo zapisi sa statusom Logged mogu biti pokrenuti. Trenutni status: {record.Status}.");

        var now = DateTime.UtcNow;
        record.Status = MaintenanceStatus.InProgress;
        record.UpdatedAtUtc = now;

        // Create MaintenanceBlock slot when Out-of-Service period is defined
        if (record.OutOfServiceFromUtc.HasValue && record.OutOfServiceToUtc.HasValue)
        {
            var fromUtc = record.OutOfServiceFromUtc.Value;
            var toUtc = record.OutOfServiceToUtc.Value;

            // Validate no overlapping MaintenanceBlock for the same dress (excluding this record)
            var hasConflict = await _context.DressAvailabilitySlots
                .AnyAsync(s => s.DressId == record.DressId
                            && !s.IsDeleted
                            && s.SlotType == AvailabilitySlotType.MaintenanceBlock
                            && s.SourceReservationId != record.Id
                            && s.StartAtUtc < toUtc
                            && s.EndAtUtc > fromUtc);

            if (hasConflict)
                throw new UserException("Odabrani period van servisa preklapa se s postojećim blokom održavanja za ovu vjenčanicu.");

            _context.DressAvailabilitySlots.Add(new DressAvailabilitySlot
            {
                DressId = record.DressId,
                StartAtUtc = fromUtc,
                EndAtUtc = toUtc,
                SlotType = AvailabilitySlotType.MaintenanceBlock,
                Reason = $"Održavanje #{record.Id}",
                SourceReservationId = record.Id,
                SourceReservationType = ReservationSourceType.Maintenance,
                CreatedAtUtc = now,
                IsDeleted = false
            });
        }

        // Set Dress.Status = OutOfService (if not Archived) and apply BeforeCondition
        var dress = await _context.Dresses.FirstOrDefaultAsync(d => d.Id == record.DressId && !d.IsDeleted);
        if (dress != null && dress.Status != DressStatus.Archived)
        {
            dress.Status = DressStatus.OutOfService;

            if (record.BeforeCondition.HasValue)
                dress.Condition = record.BeforeCondition.Value;

            dress.UpdatedAtUtc = now;
        }

        await _context.SaveChangesAsync();
        return await LoadAndMapAsync(record.Id);
    }

    public async Task<MaintenanceRecordResponse> CompleteAsync(int id)
    {
        var record = await GetRecordOrThrowAsync(id);

        if (record.Status != MaintenanceStatus.InProgress)
            throw new UserException($"Samo zapisi sa statusom InProgress mogu biti završeni. Trenutni status: {record.Status}.");

        var now = DateTime.UtcNow;
        record.Status = MaintenanceStatus.Completed;
        record.UpdatedAtUtc = now;

        // Release the MaintenanceBlock slot
        await ReleaseMaintenanceBlockAsync(record.Id, now);
        // Persist block release before status restore so availability queries see released slots.
        await _context.SaveChangesAsync();

        // Apply AfterCondition and restore Dress.Status if no other active blocks
        var dress = await _context.Dresses.FirstOrDefaultAsync(d => d.Id == record.DressId && !d.IsDeleted);
        if (dress != null)
        {
            if (record.AfterCondition.HasValue)
                dress.Condition = record.AfterCondition.Value;

            await RestoreDressStatusIfClearAsync(dress, now);
        }

        await _context.SaveChangesAsync();
        return await LoadAndMapAsync(record.Id);
    }

    public async Task<MaintenanceRecordResponse> CancelAsync(int id)
    {
        var record = await GetRecordOrThrowAsync(id);

        if (record.Status == MaintenanceStatus.Completed || record.Status == MaintenanceStatus.Cancelled)
            throw new UserException($"Zapis sa statusom '{record.Status}' ne može biti otkazan.");

        var now = DateTime.UtcNow;
        record.Status = MaintenanceStatus.Cancelled;
        record.UpdatedAtUtc = now;

        // Release the MaintenanceBlock slot (if InProgress had one)
        await ReleaseMaintenanceBlockAsync(record.Id, now);
        await _context.SaveChangesAsync();

        // Restore Dress.Status if no other active blocks remain
        var dress = await _context.Dresses.FirstOrDefaultAsync(d => d.Id == record.DressId && !d.IsDeleted);
        if (dress != null)
            await RestoreDressStatusIfClearAsync(dress, now);

        await _context.SaveChangesAsync();
        return await LoadAndMapAsync(record.Id);
    }

    // ── Manual dress condition update ─────────────────────────────────────────

    public async Task UpdateDressConditionAsync(int dressId, DressCondition condition)
    {
        var dress = await _context.Dresses
            .FirstOrDefaultAsync(d => d.Id == dressId && !d.IsDeleted);

        if (dress == null)
            throw new UserException("Vjenčanica nije pronađena.");

        dress.Condition = condition;
        dress.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }

    // ── Summary ───────────────────────────────────────────────────────────────

    public async Task<MaintenanceSummaryResponse> GetSummaryAsync(int dressId, DateTime? fromDate, DateTime? toDate)
    {
        var dress = await _context.Dresses
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.Id == dressId && !d.IsDeleted);

        if (dress == null)
            throw new UserException("Vjenčanica nije pronađena.");

        var query = _context.MaintenanceRecords
            .Where(m => m.DressId == dressId && !m.IsDeleted);

        var fromUtc = NormalizeUtc(fromDate);
        var toUtc = NormalizeUtc(toDate);

        if (fromUtc.HasValue)
            query = query.Where(m => m.PerformedAtUtc >= fromUtc.Value);
        if (toUtc.HasValue)
            query = query.Where(m => m.PerformedAtUtc <= toUtc.Value);

        var records = await query
            .Select(m => new { m.MaintenanceType, m.CostAmount })
            .ToListAsync();

        var byType = records
            .GroupBy(m => m.MaintenanceType)
            .Select(g => new MaintenanceTypeSummary
            {
                MaintenanceType = g.Key,
                MaintenanceTypeLabel = g.Key.ToString(),
                RecordCount = g.Count(),
                TotalCostAmount = g.Sum(x => x.CostAmount)
            })
            .OrderBy(t => t.MaintenanceType)
            .ToList();

        return new MaintenanceSummaryResponse
        {
            DressId = dressId,
            DressName = dress.Name,
            DressCode = dress.Code,
            FromDate = fromDate,
            ToDate = toDate,
            TotalRecordCount = records.Count,
            TotalCostAmount = records.Sum(r => r.CostAmount),
            ByType = byType
        };
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private IQueryable<MaintenanceRecord> BuildBaseQuery()
    {
        return _context.MaintenanceRecords
            .Include(m => m.Dress)
            .Include(m => m.RecordedByUser)
            .Where(m => !m.IsDeleted);
    }

    private static IQueryable<MaintenanceRecord> ApplyFilter(
        IQueryable<MaintenanceRecord> query, MaintenanceRecordSearchObject search)
    {
        if (search.DressId.HasValue)
            query = query.Where(m => m.DressId == search.DressId.Value);

        if (search.Status.HasValue)
            query = query.Where(m => m.Status == search.Status.Value);

        if (search.MaintenanceType.HasValue)
            query = query.Where(m => m.MaintenanceType == search.MaintenanceType.Value);

        if (search.RecordedByUserId.HasValue)
            query = query.Where(m => m.RecordedByUserId == search.RecordedByUserId.Value);

        if (search.FromDate.HasValue)
            query = query.Where(m => m.PerformedAtUtc >= search.FromDate.Value);

        if (search.ToDate.HasValue)
            query = query.Where(m => m.PerformedAtUtc <= search.ToDate.Value);

        if (!string.IsNullOrWhiteSpace(search.FTS))
        {
            var term = search.FTS.Trim().ToLower();
            query = query.Where(m =>
                m.Description.ToLower().Contains(term) ||
                (m.VendorName != null && m.VendorName.ToLower().Contains(term)) ||
                (m.InvoiceNumber != null && m.InvoiceNumber.ToLower().Contains(term)));
        }

        return query;
    }

    private async Task ReleaseMaintenanceBlockAsync(int maintenanceRecordId, DateTime now)
    {
        var slots = await _context.DressAvailabilitySlots
            .Where(s => s.SourceReservationId == maintenanceRecordId
                     && s.SourceReservationType == ReservationSourceType.Maintenance
                     && s.SlotType == AvailabilitySlotType.MaintenanceBlock
                     && !s.IsDeleted)
            .ToListAsync();

        foreach (var slot in slots)
        {
            slot.IsDeleted = true;
            slot.UpdatedAtUtc = now;
        }
    }

    private async Task RestoreDressStatusIfClearAsync(Dress dress, DateTime now)
    {
        if (dress.Status != DressStatus.OutOfService)
            return;

        var hasActiveMaintenanceBlock = await _context.DressAvailabilitySlots
            .AnyAsync(s => s.DressId == dress.Id
                        && !s.IsDeleted
                        && s.SlotType == AvailabilitySlotType.MaintenanceBlock);

        if (!hasActiveMaintenanceBlock)
        {
            dress.Status = DressStatus.Active;
            dress.UpdatedAtUtc = now;
        }
    }

    private async Task<MaintenanceRecord> GetRecordOrThrowAsync(int id)
    {
        var record = await _context.MaintenanceRecords
            .FirstOrDefaultAsync(m => m.Id == id && !m.IsDeleted);

        if (record == null)
            throw new UserException("Zapis o održavanju nije pronađen.");

        return record;
    }

    private async Task<MaintenanceRecordResponse> LoadAndMapAsync(int id)
    {
        var record = await BuildBaseQuery().FirstAsync(m => m.Id == id);
        return MapToResponse(record);
    }

    private static MaintenanceRecordResponse MapToResponse(MaintenanceRecord entity)
    {
        return new MaintenanceRecordResponse
        {
            Id = entity.Id,
            DressId = entity.DressId,
            DressName = entity.Dress?.Name ?? string.Empty,
            DressCode = entity.Dress?.Code ?? string.Empty,
            RecordedByUserId = entity.RecordedByUserId,
            RecordedByUserName = entity.RecordedByUser != null
                ? $"{entity.RecordedByUser.FirstName} {entity.RecordedByUser.LastName}".Trim()
                : string.Empty,
            MaintenanceType = entity.MaintenanceType,
            MaintenanceTypeLabel = entity.MaintenanceType.ToString(),
            Status = entity.Status,
            StatusLabel = entity.Status.ToString(),
            Description = entity.Description,
            CostAmount = entity.CostAmount,
            VendorName = entity.VendorName,
            InvoiceNumber = entity.InvoiceNumber,
            BeforeCondition = entity.BeforeCondition,
            BeforeConditionLabel = entity.BeforeCondition?.ToString(),
            AfterCondition = entity.AfterCondition,
            AfterConditionLabel = entity.AfterCondition?.ToString(),
            OutOfServiceFromUtc = entity.OutOfServiceFromUtc,
            OutOfServiceToUtc = entity.OutOfServiceToUtc,
            PerformedAtUtc = entity.PerformedAtUtc,
            NextCheckAtUtc = entity.NextCheckAtUtc,
            CreatedAtUtc = entity.CreatedAtUtc,
            UpdatedAtUtc = entity.UpdatedAtUtc
        };
    }

    private static void NormalizePagination(MaintenanceRecordSearchObject search)
    {
        const int maxPageSize = 100;
        if (!search.PageSize.HasValue || search.PageSize.Value <= 0)
            search.PageSize = 30;
        if (search.PageSize.Value > maxPageSize)
            search.PageSize = maxPageSize;
        if (!search.Page.HasValue || search.Page.Value < 0)
            search.Page = 0;
    }

    private static DateTime? NormalizeUtc(DateTime? dt)
        => dt.HasValue
            ? (dt.Value.Kind == DateTimeKind.Utc ? dt.Value : DateTime.SpecifyKind(dt.Value, DateTimeKind.Utc))
            : null;
}
