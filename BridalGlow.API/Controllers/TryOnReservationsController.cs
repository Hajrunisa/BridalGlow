using BridalGlow.API.Filters;
using BridalGlow.Model.Constants;
using BridalGlow.Model.Enums;
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
public class TryOnReservationsController : ControllerBase
{
    private readonly ITryOnReservationService _service;

    public TryOnReservationsController(ITryOnReservationService service)
    {
        _service = service;
    }

    // ── Staff / Admin ─────────────────────────────────────────────────────────

    /// <summary>
    /// Returns a paged list of all try-on reservations with optional filtering.
    /// Accessible by Staff and Admin only.
    /// </summary>
    [HttpGet]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<PagedResult<TryOnReservationResponse>>> GetAll(
        [FromQuery] TryOnReservationSearchObject? search = null)
    {
        return await _service.GetAsync(search ?? new TryOnReservationSearchObject());
    }

    /// <summary>
    /// Returns a single reservation by ID.
    /// Staff/Admin can access any reservation; customers can only access their own.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<TryOnReservationResponse>> GetById(int id)
    {
        var reservation = await _service.GetByIdAsync(id);
        if (reservation == null) return NotFound();

        // Customers can only view their own reservations
        if (User.IsInRole(RoleNames.Customer))
        {
            var userId = User.GetUserId();
            if (reservation.CustomerUserId != userId)
                return Forbid();
        }

        return reservation;
    }

    // ── Customer ─────────────────────────────────────────────────────────────

    /// <summary>
    /// Returns the current customer's own reservations.
    /// </summary>
    [HttpGet("mine")]
    [Authorize(Roles = RoleNames.Customer)]
    public async Task<ActionResult<PagedResult<TryOnReservationResponse>>> GetMine(
        [FromQuery] TryOnReservationSearchObject? search = null)
    {
        var customerId = User.GetUserId();
        return await _service.GetMyReservationsAsync(customerId, search ?? new TryOnReservationSearchObject());
    }

    /// <summary>
    /// Creates a new try-on reservation.
    /// The slot must be free (Available) and the dress must exist.
    /// </summary>
    [HttpPost]
    [Authorize(Roles = RoleNames.Customer)]
    public async Task<ActionResult<TryOnReservationResponse>> Create(
        [FromBody] TryOnReservationCreateRequest request)
    {
        var customerId = User.GetUserId();
        var created = await _service.CreateAsync(customerId, request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>
    /// Cancels a reservation. Customers can only cancel their own.
    /// Staff can cancel any reservation.
    /// </summary>
    [HttpPost("{id:int}/cancel")]
    public async Task<ActionResult<TryOnReservationResponse>> Cancel(
        int id, [FromBody] TryOnReservationCancelRequest? request = null)
    {
        var userId = User.GetUserId();
        var isStaff = User.IsInRole(RoleNames.Admin) || User.IsInRole(RoleNames.SalonStaff);
        return await _service.CancelAsync(id, userId, isStaff, request ?? new TryOnReservationCancelRequest());
    }

    // ── Staff actions ─────────────────────────────────────────────────────────

    /// <summary>
    /// Confirms a pending reservation (Pending → Confirmed).
    /// </summary>
    [HttpPost("{id:int}/confirm")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<TryOnReservationResponse>> Confirm(
        int id, [FromBody] TryOnReservationStatusChangeRequest? request = null)
    {
        var staffUserId = User.GetUserId();
        return await _service.ConfirmAsync(id, staffUserId, request ?? new TryOnReservationStatusChangeRequest());
    }

    /// <summary>
    /// Marks a reservation as completed (Confirmed/CheckedIn → Completed).
    /// </summary>
    [HttpPost("{id:int}/complete")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<TryOnReservationResponse>> Complete(
        int id, [FromBody] TryOnReservationStatusChangeRequest? request = null)
    {
        var staffUserId = User.GetUserId();
        return await _service.CompleteAsync(id, staffUserId, request ?? new TryOnReservationStatusChangeRequest());
    }

    /// <summary>
    /// Marks a confirmed reservation as no-show (Confirmed → NoShow).
    /// </summary>
    [HttpPost("{id:int}/no-show")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<TryOnReservationResponse>> NoShow(
        int id, [FromBody] TryOnReservationStatusChangeRequest? request = null)
    {
        var staffUserId = User.GetUserId();
        return await _service.MarkNoShowAsync(id, staffUserId, request ?? new TryOnReservationStatusChangeRequest());
    }
}
