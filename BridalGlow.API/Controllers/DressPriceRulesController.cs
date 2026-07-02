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
public class DressPriceRulesController : ControllerBase
{
    private readonly IDressPriceRuleService _service;

    public DressPriceRulesController(IDressPriceRuleService service)
    {
        _service = service;
    }

    /// <summary>
    /// Returns a paged list of price rules, filterable by DressId, RuleType, and IsActive.
    /// </summary>
    [HttpGet]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<PagedResult<DressPriceRuleResponse>>> Get(
        [FromQuery] DressPriceRuleSearchObject? search = null)
    {
        return await _service.GetAsync(search ?? new DressPriceRuleSearchObject());
    }

    /// <summary>
    /// Returns a single price rule by ID.
    /// </summary>
    [HttpGet("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressPriceRuleResponse>> GetById(int id)
    {
        var rule = await _service.GetByIdAsync(id);
        if (rule == null) return NotFound();
        return rule;
    }

    /// <summary>
    /// Returns the effective price for a dress in the given period.
    /// Accessible by all authenticated users.
    /// </summary>
    [HttpGet("effective-price")]
    public async Task<ActionResult<EffectivePriceResponse>> GetEffectivePrice(
        [FromQuery] int dressId,
        [FromQuery] DateTime startAt,
        [FromQuery] DateTime endAt)
    {
        if (dressId <= 0)
            return BadRequest(new { errors = new { userError = new[] { "DressId je obavezan." } } });

        if (startAt >= endAt)
            return BadRequest(new { errors = new { userError = new[] { "StartAt mora biti prije EndAt." } } });

        var result = await _service.GetEffectivePriceAsync(dressId, startAt, endAt);
        return result;
    }

    /// <summary>
    /// Creates a new price rule for a dress.
    /// </summary>
    [HttpPost]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressPriceRuleResponse>> Create(
        [FromBody] DressPriceRuleCreateRequest request)
    {
        var created = await _service.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>
    /// Updates an existing price rule.
    /// </summary>
    [HttpPut("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressPriceRuleResponse>> Update(
        int id, [FromBody] DressPriceRuleUpdateRequest request)
    {
        var updated = await _service.UpdateAsync(id, request);
        if (updated == null) return NotFound();
        return updated;
    }

    /// <summary>
    /// Soft-deletes a price rule.
    /// </summary>
    [HttpDelete("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _service.DeleteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
