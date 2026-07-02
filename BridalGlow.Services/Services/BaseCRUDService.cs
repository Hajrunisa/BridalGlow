using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public abstract class BaseCRUDService<T, TSearch, TEntity, TInsert, TUpdate>
    : BaseService<T, TSearch, TEntity>, ICRUDService<T, TSearch, TInsert, TUpdate>
    where T : class
    where TSearch : BaseSearchObject
    where TEntity : class, new()
    where TInsert : class
    where TUpdate : class
{
    protected BaseCRUDService(BridalGlowDbContext context, IMapper mapper) : base(context, mapper)
    {
    }

    public virtual async Task<T> CreateAsync(TInsert request)
    {
        var entity = new TEntity();
        MapInsertToEntity(entity, request);

        if (entity is AuditableEntity auditable)
        {
            auditable.CreatedAtUtc = DateTime.UtcNow;
            auditable.IsDeleted = false;
        }

        _context.Set<TEntity>().Add(entity);
        await BeforeInsert(entity, request);
        await _context.SaveChangesAsync();

        return MapToResponse(entity);
    }

    public virtual async Task<T?> UpdateAsync(int id, TUpdate request)
    {
        var entity = await _context.Set<TEntity>().FindAsync(id);
        if (entity == null)
            return null;

        if (entity is AuditableEntity { IsDeleted: true })
            return null;

        await BeforeUpdate(entity, request);
        MapUpdateToEntity(entity, request);

        if (entity is AuditableEntity auditable)
            auditable.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return MapToResponse(entity);
    }

    public virtual async Task<bool> DeleteAsync(int id)
    {
        var entity = await _context.Set<TEntity>().FindAsync(id);
        if (entity == null)
            return false;

        if (entity is AuditableEntity { IsDeleted: true })
            return false;

        await BeforeDelete(entity);

        if (entity is AuditableEntity auditable)
        {
            auditable.IsDeleted = true;
            auditable.UpdatedAtUtc = DateTime.UtcNow;
        }
        else
        {
            _context.Set<TEntity>().Remove(entity);
        }

        await _context.SaveChangesAsync();
        return true;
    }

    protected virtual Task BeforeInsert(TEntity entity, TInsert request) => Task.CompletedTask;

    protected virtual Task BeforeUpdate(TEntity entity, TUpdate request) => Task.CompletedTask;

    protected virtual Task BeforeDelete(TEntity entity) => Task.CompletedTask;

    protected virtual void MapInsertToEntity(TEntity entity, TInsert request) =>
        _mapper.Map(request, entity);

    protected virtual void MapUpdateToEntity(TEntity entity, TUpdate request) =>
        _mapper.Map(request, entity);
}
