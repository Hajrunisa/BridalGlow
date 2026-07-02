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

public class DressTagService
    : BaseCRUDService<DressTagResponse, DressTagSearchObject, DressTag, DressTagUpsertRequest, DressTagUpsertRequest>,
      IDressTagService
{
    public DressTagService(BridalGlowDbContext context, IMapper mapper) : base(context, mapper)
    {
    }

    public override async Task<DressTagResponse?> GetByIdAsync(int id)
    {
        var entity = await _context.DressTags
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.Id == id && !t.IsDeleted);

        return entity == null ? null : MapToResponse(entity);
    }

    protected override IQueryable<DressTag> ApplyFilter(IQueryable<DressTag> query, DressTagSearchObject search)
    {
        if (!search.IncludeDeleted)
            query = query.Where(t => !t.IsDeleted);

        if (!string.IsNullOrWhiteSpace(search.Name))
            query = query.Where(t => t.Name.Contains(search.Name));

        if (!string.IsNullOrWhiteSpace(search.FTS))
            query = query.Where(t => t.Name.Contains(search.FTS));

        return query.OrderBy(t => t.Name);
    }

    protected override void MapInsertToEntity(DressTag entity, DressTagUpsertRequest request)
    {
        entity.Name = request.Name.Trim();
    }

    protected override void MapUpdateToEntity(DressTag entity, DressTagUpsertRequest request)
    {
        entity.Name = request.Name.Trim();
    }

    protected override DressTagResponse MapToResponse(DressTag entity) => new()
    {
        Id = entity.Id,
        Name = entity.Name,
        CreatedAtUtc = entity.CreatedAtUtc
    };

    protected override async Task BeforeInsert(DressTag entity, DressTagUpsertRequest request)
    {
        if (await _context.DressTags.AnyAsync(t => t.Name == entity.Name))
            throw new UserException("Tag sa tim nazivom već postoji.");
    }

    protected override async Task BeforeUpdate(DressTag entity, DressTagUpsertRequest request)
    {
        if (await _context.DressTags.AnyAsync(t => t.Name == entity.Name && t.Id != entity.Id))
            throw new UserException("Tag sa tim nazivom već postoji.");
    }

    protected override async Task BeforeDelete(DressTag entity)
    {
        var isUsed = await _context.DressTagMaps.AnyAsync(m => m.DressTagId == entity.Id && !m.IsDeleted);
        if (isUsed)
            throw new UserException("Brisanje nije moguće jer tag koriste vjenčanice u katalogu.");
    }
}
