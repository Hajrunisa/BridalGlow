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
public class DressTagController : ControllerBase
{
    private readonly IDressTagService _dressTagService;

    public DressTagController(IDressTagService dressTagService)
    {
        _dressTagService = dressTagService;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResult<DressTagResponse>>> Get([FromQuery] DressTagSearchObject? search = null)
    {
        return await _dressTagService.GetAsync(search ?? new DressTagSearchObject());
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<DressTagResponse>> GetById(int id)
    {
        var tag = await _dressTagService.GetByIdAsync(id);
        if (tag == null)
            return NotFound();

        return tag;
    }

    [HttpPost]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressTagResponse>> Create([FromBody] DressTagUpsertRequest request)
    {
        var created = await _dressTagService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressTagResponse>> Update(int id, [FromBody] DressTagUpsertRequest request)
    {
        var updated = await _dressTagService.UpdateAsync(id, request);
        if (updated == null)
            return NotFound();

        return updated;
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _dressTagService.DeleteAsync(id);
        if (!deleted)
            return NotFound();

        return NoContent();
    }
}
