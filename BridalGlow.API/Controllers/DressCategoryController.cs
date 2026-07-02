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
public class DressCategoryController : ControllerBase
{
    private readonly IDressCategoryService _dressCategoryService;

    public DressCategoryController(IDressCategoryService dressCategoryService)
    {
        _dressCategoryService = dressCategoryService;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResult<DressCategoryResponse>>> Get([FromQuery] DressCategorySearchObject? search = null)
    {
        return await _dressCategoryService.GetAsync(search ?? new DressCategorySearchObject());
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<DressCategoryResponse>> GetById(int id)
    {
        var category = await _dressCategoryService.GetByIdAsync(id);
        if (category == null)
            return NotFound();

        return category;
    }

    [HttpPost]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressCategoryResponse>> Create([FromBody] DressCategoryUpsertRequest request)
    {
        var created = await _dressCategoryService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressCategoryResponse>> Update(int id, [FromBody] DressCategoryUpsertRequest request)
    {
        var updated = await _dressCategoryService.UpdateAsync(id, request);
        if (updated == null)
            return NotFound();

        return updated;
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _dressCategoryService.DeleteAsync(id);
        if (!deleted)
            return NotFound();

        return NoContent();
    }
}
