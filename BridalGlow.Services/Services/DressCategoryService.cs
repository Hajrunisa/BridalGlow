using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public class DressCategoryService
    : BaseCRUDService<DressCategoryResponse, DressCategorySearchObject, DressCategory, DressCategoryUpsertRequest, DressCategoryUpsertRequest>,
      IDressCategoryService
{
    public DressCategoryService(BridalGlowDbContext context, IMapper mapper) : base(context, mapper)
    {
    }

    public override async Task<DressCategoryResponse?> GetByIdAsync(int id)
    {
        var entity = await _context.DressCategories
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == id && !c.IsDeleted);

        return entity == null ? null : MapToResponse(entity);
    }

    protected override IQueryable<DressCategory> ApplyFilter(IQueryable<DressCategory> query, DressCategorySearchObject search)
    {
        if (!search.IncludeDeleted)
            query = query.Where(c => !c.IsDeleted);

        if (!string.IsNullOrWhiteSpace(search.Name))
            query = query.Where(c => c.Name.Contains(search.Name));

        if (!string.IsNullOrWhiteSpace(search.FTS))
            query = query.Where(c =>
                c.Name.Contains(search.FTS) ||
                (c.Description != null && c.Description.Contains(search.FTS)));

        return query.OrderBy(c => c.Name);
    }

    protected override void MapInsertToEntity(DressCategory entity, DressCategoryUpsertRequest request)
    {
        entity.Name = request.Name.Trim();
        entity.Description = request.Description?.Trim();
    }

    protected override void MapUpdateToEntity(DressCategory entity, DressCategoryUpsertRequest request)
    {
        entity.Name = request.Name.Trim();
        entity.Description = request.Description?.Trim();
    }

    protected override DressCategoryResponse MapToResponse(DressCategory entity) => new()
    {
        Id = entity.Id,
        Name = entity.Name,
        Description = entity.Description,
        CreatedAtUtc = entity.CreatedAtUtc
    };

    protected override async Task BeforeInsert(DressCategory entity, DressCategoryUpsertRequest request)
    {
        if (await _context.DressCategories.AnyAsync(c => c.Name == entity.Name))
            throw new UserException("Kategorija sa tim nazivom već postoji.");
    }

    protected override async Task BeforeUpdate(DressCategory entity, DressCategoryUpsertRequest request)
    {
        if (await _context.DressCategories.AnyAsync(c => c.Name == entity.Name && c.Id != entity.Id))
            throw new UserException("Kategorija sa tim nazivom već postoji.");
    }

    protected override async Task BeforeDelete(DressCategory entity)
    {
        var isUsed = await _context.Dresses.AnyAsync(d => d.PrimaryCategoryId == entity.Id && !d.IsDeleted);
        if (isUsed)
            throw new UserException("Brisanje nije moguće jer kategoriju koriste vjenčanice u katalogu.");
    }
}
