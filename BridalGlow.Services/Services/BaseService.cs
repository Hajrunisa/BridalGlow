using BridalGlow.Data.Database;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public abstract class BaseService<T, TSearch, TEntity> : IService<T, TSearch>
    where T : class
    where TSearch : BaseSearchObject
    where TEntity : class
{
    protected const int MaxPageSize = 100;

    protected readonly BridalGlowDbContext _context;
    protected readonly IMapper _mapper;

    protected BaseService(BridalGlowDbContext context, IMapper mapper)
    {
        _context = context;
        _mapper = mapper;
    }

    public virtual async Task<PagedResult<T>> GetAsync(TSearch search)
    {
        NormalizePagination(search);

        var query = _context.Set<TEntity>().AsQueryable();
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

        var list = await query.ToListAsync();
        return new PagedResult<T>
        {
            Items = list.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    protected static void NormalizePagination(TSearch search)
    {
        if (!search.PageSize.HasValue || search.PageSize.Value <= 0)
            search.PageSize = 30;

        if (search.PageSize.Value > MaxPageSize)
            search.PageSize = MaxPageSize;

        if (!search.Page.HasValue || search.Page.Value < 0)
            search.Page = 0;
    }

    public virtual async Task<T?> GetByIdAsync(int id)
    {
        var entity = await _context.Set<TEntity>().FindAsync(id);
        return entity == null ? null : MapToResponse(entity);
    }

    protected virtual IQueryable<TEntity> ApplyFilter(IQueryable<TEntity> query, TSearch search) => query;

    protected virtual T MapToResponse(TEntity entity) => _mapper.Map<T>(entity);
}
