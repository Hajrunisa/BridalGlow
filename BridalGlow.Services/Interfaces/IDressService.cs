using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IDressService
    : ICRUDService<DressResponse, DressSearchObject, DressUpsertRequest, DressUpsertRequest>
{
    Task<PagedResult<DressListItemResponse>> GetListAsync(DressSearchObject search);
    Task<DressResponse?> ArchiveAsync(int id);
}
