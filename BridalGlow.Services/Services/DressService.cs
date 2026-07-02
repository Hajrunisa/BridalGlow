using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public class DressService
    : BaseCRUDService<DressResponse, DressSearchObject, Dress, DressUpsertRequest, DressUpsertRequest>,
      IDressService
{
    public DressService(BridalGlowDbContext context, IMapper mapper) : base(context, mapper)
    {
    }

    // --- Read ---

    public override async Task<DressResponse?> GetByIdAsync(int id)
    {
        var entity = await _context.Dresses
            .Include(d => d.PrimaryCategory)
            .Include(d => d.TagMaps.Where(m => !m.IsDeleted))
                .ThenInclude(m => m.DressTag)
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.Id == id && !d.IsDeleted);

        return entity == null ? null : MapToResponse(entity);
    }

    public override async Task<PagedResult<DressResponse>> GetAsync(DressSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery(search);

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

        var list = await query.AsSplitQuery().ToListAsync();
        return new PagedResult<DressResponse>
        {
            Items = list.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    public async Task<PagedResult<DressListItemResponse>> GetListAsync(DressSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery(search);

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

        var list = await query.AsSplitQuery().ToListAsync();
        return new PagedResult<DressListItemResponse>
        {
            Items = list.Select(MapToListItemResponse).ToList(),
            TotalCount = totalCount
        };
    }

    // --- Archive ---

    public async Task<DressResponse?> ArchiveAsync(int id)
    {
        var entity = await _context.Dresses.FindAsync(id);
        if (entity == null || entity.IsDeleted)
            return null;

        if (entity.Status == DressStatus.Archived)
            throw new UserException("Vjenčanica je već arhivirana.");

        var hasActiveReservations = await HasActiveReservationsAsync(entity.Id);
        if (hasActiveReservations)
            throw new UserException("Arhiviranje nije moguće jer vjenčanica ima aktivne rezervacije.");

        entity.Status = DressStatus.Archived;
        entity.UpdatedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return await GetByIdAsync(id);
    }

    // --- Create override (handle TagIds via navigation property) ---

    public override async Task<DressResponse> CreateAsync(DressUpsertRequest request)
    {
        await ValidateCategoryExistsAsync(request.PrimaryCategoryId);
        await ValidateTagIdsAsync(request.TagIds);

        if (await _context.Dresses.AnyAsync(d => d.Code == request.Code.Trim()))
            throw new UserException("Vjenčanica s ovom šifrom već postoji.");

        var entity = new Dress();
        MapInsertToEntity(entity, request);
        entity.CreatedAtUtc = DateTime.UtcNow;
        entity.IsDeleted = false;
        entity.AverageRating = 0;
        entity.RatingCount = 0;

        if (request.TagIds != null && request.TagIds.Count > 0)
        {
            entity.TagMaps = request.TagIds.Distinct().Select(tagId => new DressTagMap
            {
                DressTagId = tagId,
                CreatedAtUtc = DateTime.UtcNow,
                IsDeleted = false
            }).ToList();
        }

        _context.Dresses.Add(entity);
        await _context.SaveChangesAsync();

        return (await GetByIdAsync(entity.Id))!;
    }

    // --- Update override (handle TagIds synchronization) ---

    public override async Task<DressResponse?> UpdateAsync(int id, DressUpsertRequest request)
    {
        var entity = await _context.Dresses.FindAsync(id);
        if (entity == null || entity.IsDeleted)
            return null;

        await ValidateCategoryExistsAsync(request.PrimaryCategoryId);
        await ValidateTagIdsAsync(request.TagIds);

        if (await _context.Dresses.AnyAsync(d => d.Code == request.Code.Trim() && d.Id != id))
            throw new UserException("Vjenčanica s ovom šifrom već postoji.");

        await SyncTagMapsAsync(entity.Id, request.TagIds ?? new List<int>());

        MapUpdateToEntity(entity, request);
        entity.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return await GetByIdAsync(id);
    }

    // --- Delete override (soft-delete TagMaps, check reservations) ---

    protected override async Task BeforeDelete(Dress entity)
    {
        var hasActiveReservations = await HasActiveReservationsAsync(entity.Id);
        if (hasActiveReservations)
            throw new UserException("Brisanje nije moguće jer vjenčanica ima aktivne rezervacije.");

        // Soft-delete all active tag maps so that DressTag delete protection works correctly
        var activeMaps = await _context.DressTagMaps
            .Where(m => m.DressId == entity.Id && !m.IsDeleted)
            .ToListAsync();

        foreach (var map in activeMaps)
        {
            map.IsDeleted = true;
            map.UpdatedAtUtc = DateTime.UtcNow;
        }
    }

    // --- Filter ---

    protected override IQueryable<Dress> ApplyFilter(IQueryable<Dress> query, DressSearchObject search)
    {
        if (!search.IncludeDeleted)
            query = query.Where(d => !d.IsDeleted);

        if (!string.IsNullOrWhiteSpace(search.Name))
            query = query.Where(d => d.Name.Contains(search.Name));

        if (!string.IsNullOrWhiteSpace(search.Code))
            query = query.Where(d => d.Code.Contains(search.Code));

        if (search.CategoryId.HasValue)
            query = query.Where(d => d.PrimaryCategoryId == search.CategoryId.Value);

        if (search.TagId.HasValue)
            query = query.Where(d => d.TagMaps.Any(m => m.DressTagId == search.TagId.Value && !m.IsDeleted));

        if (search.Status.HasValue)
            query = query.Where(d => d.Status == search.Status.Value);

        if (search.Condition.HasValue)
            query = query.Where(d => d.Condition == search.Condition.Value);

        if (!string.IsNullOrWhiteSpace(search.SizeLabel))
            query = query.Where(d => d.SizeLabel == search.SizeLabel);

        if (search.MinPrice.HasValue)
            query = query.Where(d => d.BaseRentalPrice >= search.MinPrice.Value);

        if (search.MaxPrice.HasValue)
            query = query.Where(d => d.BaseRentalPrice <= search.MaxPrice.Value);

        if (search.IsFeatured.HasValue)
            query = query.Where(d => d.IsFeatured == search.IsFeatured.Value);

        if (search.MinRating.HasValue)
            query = query.Where(d => d.AverageRating >= search.MinRating.Value);

        if (!string.IsNullOrWhiteSpace(search.FTS))
            query = query.Where(d =>
                d.Name.Contains(search.FTS) ||
                d.Code.Contains(search.FTS) ||
                (d.Description != null && d.Description.Contains(search.FTS)) ||
                (d.Brand != null && d.Brand.Contains(search.FTS)));

        query = ApplySorting(query, search);

        return query;
    }

    // --- Mapping ---

    protected override DressResponse MapToResponse(Dress entity) => new()
    {
        Id = entity.Id,
        Code = entity.Code,
        Name = entity.Name,
        Description = entity.Description,
        Brand = entity.Brand,
        Color = entity.Color,
        Material = entity.Material,
        Silhouette = entity.Silhouette,
        Neckline = entity.Neckline,
        SleeveType = entity.SleeveType,
        TrainLength = entity.TrainLength,
        SizeLabel = entity.SizeLabel,
        BustCm = entity.BustCm,
        WaistCm = entity.WaistCm,
        HipCm = entity.HipCm,
        LengthCm = entity.LengthCm,
        Condition = entity.Condition,
        AcquisitionCost = entity.AcquisitionCost,
        ReplacementValue = entity.ReplacementValue,
        BaseRentalPrice = entity.BaseRentalPrice,
        TryOnPrice = entity.TryOnPrice,
        DepositAmount = entity.DepositAmount,
        Status = entity.Status,
        IsFeatured = entity.IsFeatured,
        AverageRating = entity.AverageRating,
        RatingCount = entity.RatingCount,
        PrimaryCategoryId = entity.PrimaryCategoryId,
        PrimaryCategoryName = entity.PrimaryCategory?.Name ?? string.Empty,
        Tags = entity.TagMaps
            .Where(m => !m.IsDeleted && m.DressTag != null)
            .Select(m => new DressTagResponse { Id = m.DressTag.Id, Name = m.DressTag.Name, CreatedAtUtc = m.DressTag.CreatedAtUtc })
            .ToList(),
        CreatedAtUtc = entity.CreatedAtUtc,
        UpdatedAtUtc = entity.UpdatedAtUtc
    };

    private static DressListItemResponse MapToListItemResponse(Dress entity)
        => DressListItemMapper.Map(entity);

    protected override void MapInsertToEntity(Dress entity, DressUpsertRequest request)
    {
        entity.Code = request.Code.Trim();
        entity.Name = request.Name.Trim();
        entity.Description = request.Description?.Trim();
        entity.Brand = request.Brand?.Trim();
        entity.Color = request.Color.Trim();
        entity.Material = request.Material?.Trim();
        entity.Silhouette = request.Silhouette?.Trim();
        entity.Neckline = request.Neckline?.Trim();
        entity.SleeveType = request.SleeveType?.Trim();
        entity.TrainLength = request.TrainLength?.Trim();
        entity.SizeLabel = request.SizeLabel.Trim();
        entity.BustCm = request.BustCm;
        entity.WaistCm = request.WaistCm;
        entity.HipCm = request.HipCm;
        entity.LengthCm = request.LengthCm;
        entity.Condition = request.Condition;
        entity.AcquisitionCost = request.AcquisitionCost;
        entity.ReplacementValue = request.ReplacementValue;
        entity.BaseRentalPrice = request.BaseRentalPrice;
        entity.TryOnPrice = request.TryOnPrice;
        entity.DepositAmount = request.DepositAmount;
        entity.Status = request.Status;
        entity.IsFeatured = request.IsFeatured;
        entity.PrimaryCategoryId = request.PrimaryCategoryId;
    }

    protected override void MapUpdateToEntity(Dress entity, DressUpsertRequest request)
        => MapInsertToEntity(entity, request);

    // --- Private helpers ---

    private IQueryable<Dress> BuildBaseQuery(DressSearchObject search)
    {
        var query = _context.Dresses
            .Include(d => d.PrimaryCategory)
            .Include(d => d.Images.Where(i => i.IsPrimary && !i.IsDeleted))
            .Include(d => d.TagMaps.Where(m => !m.IsDeleted))
                .ThenInclude(m => m.DressTag)
            .AsNoTracking()
            .AsQueryable();

        return ApplyFilter(query, search);
    }

    private static IQueryable<Dress> ApplySorting(IQueryable<Dress> query, DressSearchObject search)
    {
        return search.SortBy?.ToLowerInvariant() switch
        {
            "price" => search.Descending
                ? query.OrderByDescending(d => d.BaseRentalPrice)
                : query.OrderBy(d => d.BaseRentalPrice),
            "rating" => search.Descending
                ? query.OrderByDescending(d => d.AverageRating)
                : query.OrderBy(d => d.AverageRating),
            "createdat" => search.Descending
                ? query.OrderByDescending(d => d.CreatedAtUtc)
                : query.OrderBy(d => d.CreatedAtUtc),
            _ => search.Descending
                ? query.OrderByDescending(d => d.Name)
                : query.OrderBy(d => d.Name)
        };
    }

    private async Task SyncTagMapsAsync(int dressId, List<int> newTagIds)
    {
        var allMaps = await _context.DressTagMaps
            .Where(m => m.DressId == dressId)
            .ToListAsync();

        var requestedIds = newTagIds.Distinct().ToHashSet();
        var activeIds = allMaps.Where(m => !m.IsDeleted).Select(m => m.DressTagId).ToHashSet();

        // Soft-delete tags that are no longer requested
        foreach (var map in allMaps.Where(m => !m.IsDeleted && !requestedIds.Contains(m.DressTagId)))
        {
            map.IsDeleted = true;
            map.UpdatedAtUtc = DateTime.UtcNow;
        }

        // Add or restore tags
        foreach (var tagId in requestedIds)
        {
            if (activeIds.Contains(tagId))
                continue;

            var softDeleted = allMaps.FirstOrDefault(m => m.DressTagId == tagId && m.IsDeleted);
            if (softDeleted != null)
            {
                // Restore instead of inserting to preserve the unique index
                softDeleted.IsDeleted = false;
                softDeleted.UpdatedAtUtc = DateTime.UtcNow;
            }
            else
            {
                _context.DressTagMaps.Add(new DressTagMap
                {
                    DressId = dressId,
                    DressTagId = tagId,
                    CreatedAtUtc = DateTime.UtcNow,
                    IsDeleted = false
                });
            }
        }
    }

    private async Task<bool> HasActiveReservationsAsync(int dressId)
    {
        var activeStatuses = new[]
        {
            TryOnReservationStatus.Pending,
            TryOnReservationStatus.Confirmed,
            TryOnReservationStatus.CheckedIn
        };

        var hasActiveTryOn = await _context.TryOnReservations
            .AnyAsync(r => r.DressId == dressId && activeStatuses.Contains(r.Status));

        if (hasActiveTryOn) return true;

        var activeRentalStatuses = new[]
        {
            RentalReservationStatus.Pending,
            RentalReservationStatus.Approved,
            RentalReservationStatus.AwaitingPayment,
            RentalReservationStatus.Paid,
            RentalReservationStatus.ReadyForPickup,
            RentalReservationStatus.PickedUp
        };

        return await _context.RentalReservations
            .AnyAsync(r => r.DressId == dressId && activeRentalStatuses.Contains(r.Status));
    }

    private async Task ValidateCategoryExistsAsync(int categoryId)
    {
        var exists = await _context.DressCategories.AnyAsync(c => c.Id == categoryId && !c.IsDeleted);
        if (!exists)
            throw new UserException("Odabrana kategorija ne postoji ili je obrisana.");
    }

    private async Task ValidateTagIdsAsync(List<int>? tagIds)
    {
        if (tagIds == null || tagIds.Count == 0)
            return;

        var distinctIds = tagIds.Distinct().ToList();
        var validCount = await _context.DressTags
            .CountAsync(t => distinctIds.Contains(t.Id) && !t.IsDeleted);

        if (validCount != distinctIds.Count)
            throw new UserException("Jedan ili više odabranih tagova ne postoji ili je obrisan.");
    }
}
