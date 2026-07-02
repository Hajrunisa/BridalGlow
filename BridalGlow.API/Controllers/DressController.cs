using BridalGlow.Model.Constants;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DressController : ControllerBase
{
    private readonly IDressService _dressService;
    private readonly IRecommendationQueryService _recommendationQueryService;

    public DressController(
        IDressService dressService,
        IRecommendationQueryService recommendationQueryService)
    {
        _dressService = dressService;
        _recommendationQueryService = recommendationQueryService;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResult<DressListItemResponse>>> Get([FromQuery] DressSearchObject? search = null)
    {
        var searchObj = search ?? new DressSearchObject();

        // Customers cannot include soft-deleted dresses in the listing
        if (!User.IsInRole(RoleNames.Admin) && !User.IsInRole(RoleNames.SalonStaff))
            searchObj.IncludeDeleted = false;

        return await _dressService.GetListAsync(searchObj);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<DressResponse>> GetById(int id)
    {
        var dress = await _dressService.GetByIdAsync(id);
        if (dress == null)
            return NotFound();

        return dress;
    }

    /// <summary>
    /// Returns item-based similar dresses for the given dress.
    /// </summary>
    [HttpGet("{id:int}/similar")]
    [Authorize(Roles = RoleNames.Customer)]
    public async Task<ActionResult<IReadOnlyList<SimilarDressResponse>>> GetSimilar(
        int id,
        [FromQuery] int? limit = null)
    {
        return Ok(await _recommendationQueryService.GetSimilarDressesAsync(id, limit));
    }

    [HttpPost]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressResponse>> Create([FromBody] DressUpsertRequest request)
    {
        var created = await _dressService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressResponse>> Update(int id, [FromBody] DressUpsertRequest request)
    {
        var updated = await _dressService.UpdateAsync(id, request);
        if (updated == null)
            return NotFound();

        return updated;
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _dressService.DeleteAsync(id);
        if (!deleted)
            return NotFound();

        return NoContent();
    }

    [HttpPost("{id:int}/archive")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressResponse>> Archive(int id)
    {
        var result = await _dressService.ArchiveAsync(id);
        if (result == null)
            return NotFound();

        return result;
    }
}
