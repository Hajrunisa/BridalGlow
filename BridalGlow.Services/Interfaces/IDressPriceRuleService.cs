using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IDressPriceRuleService
{
    Task<PagedResult<DressPriceRuleResponse>> GetAsync(DressPriceRuleSearchObject search);
    Task<DressPriceRuleResponse?> GetByIdAsync(int id);
    Task<DressPriceRuleResponse> CreateAsync(DressPriceRuleCreateRequest request);
    Task<DressPriceRuleResponse?> UpdateAsync(int id, DressPriceRuleUpdateRequest request);
    Task<bool> DeleteAsync(int id);
    Task<EffectivePriceResponse> GetEffectivePriceAsync(int dressId, DateTime startAt, DateTime endAt);
}
