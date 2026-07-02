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
public class DressAvailabilitySlotsController : ControllerBase
{
    private readonly IDressAvailabilitySlotService _service;

    public DressAvailabilitySlotsController(IDressAvailabilitySlotService service)
    {
        _service = service;
    }

    /// <summary>
    /// Returns a paged list of availability slots, filterable by DressId, date range, and SlotType.
    /// Accessible by Staff and Admin only.
    /// </summary>
    [HttpGet]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<PagedResult<DressAvailabilitySlotResponse>>> Get(
        [FromQuery] DressAvailabilitySlotSearchObject? search = null)
    {
        return await _service.GetAsync(search ?? new DressAvailabilitySlotSearchObject());
    }

    /// <summary>
    /// Returns a single availability slot by ID.
    /// Accessible by Staff and Admin only.
    /// </summary>
    [HttpGet("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressAvailabilitySlotResponse>> GetById(int id)
    {
        var slot = await _service.GetByIdAsync(id);
        if (slot == null) return NotFound();
        return slot;
    }

    /// <summary>
    /// Returns free (Available, non-blocked) slots for a specific dress on a given date.
    /// Accessible by all authenticated users (customers need this to book a try-on).
    /// </summary>
    [HttpGet("free-slots")]
    public async Task<ActionResult<List<DressAvailabilitySlotResponse>>> GetFreeSlots(
        [FromQuery] int dressId,
        [FromQuery] DateTime date)
    {
        if (dressId <= 0)
            return BadRequest(new { errors = new { userError = new[] { "DressId je obavezan." } } });

        var slots = await _service.GetFreeSlotsAsync(dressId, date);
        return slots;
    }

    /// <summary>
    /// Returns all availability slots (Available + blocking) for a dress within the next year.
    /// Accessible by all authenticated users so the mobile rental booking calendar
    /// can highlight available periods and disable blocked dates.
    /// </summary>
    [HttpGet("rental-availability")]
    public async Task<ActionResult<List<DressAvailabilitySlotResponse>>> GetRentalAvailability(
        [FromQuery] int dressId)
    {
        if (dressId <= 0)
            return BadRequest(new { errors = new { userError = new[] { "DressId je obavezan." } } });

        var slots = await _service.GetRentalAvailabilityAsync(dressId);
        return slots;
    }

    /// <summary>
    /// Creates a new availability slot (Available or Blocked type).
    /// TryOnHold and RentalHold are managed automatically by the reservation system.
    /// </summary>
    [HttpPost]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressAvailabilitySlotResponse>> Create(
        [FromBody] DressAvailabilitySlotCreateRequest request)
    {
        var created = await _service.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>
    /// Soft-deletes a slot. System-managed slots (TryOnHold / RentalHold) cannot be deleted manually.
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
