using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;

namespace BridalGlow.Services.Interfaces;

public interface IDressTagService
    : ICRUDService<DressTagResponse, DressTagSearchObject, DressTagUpsertRequest, DressTagUpsertRequest>
{
}
