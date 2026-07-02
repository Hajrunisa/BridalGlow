using System.Collections.Generic;
using System.Threading.Tasks;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IService<T, TSearch>
    where T : class
    where TSearch : BaseSearchObject
{
    Task<PagedResult<T>> GetAsync(TSearch search);
    Task<T?> GetByIdAsync(int id);
}
