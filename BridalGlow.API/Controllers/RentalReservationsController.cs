using BridalGlow.API.Filters;
using BridalGlow.Model.Constants;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/RentalReservations")]
[Authorize]
public class RentalReservationsController : ControllerBase
{
    private readonly IRentalReservationService _service;

    public RentalReservationsController(IRentalReservationService service)
    {
        _service = service;
    }

    // ── Staff / Admin ─────────────────────────────────────────────────────────

    /// <summary>
    /// Returns a paged list of all rental reservations with optional filtering.
    /// Accessible by Staff and Admin only.
    /// </summary>
    [HttpGet]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<PagedResult<RentalReservationResponse>>> GetAll(
        [FromQuery] RentalReservationSearchObject? search = null)
    {
        return await _service.GetAsync(search ?? new RentalReservationSearchObject());
    }

    /// <summary>
    /// Returns a single rental reservation by ID.
    /// Staff/Admin can access any reservation; customers can only access their own.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<RentalReservationResponse>> GetById(int id)
    {
        var userId = User.GetUserId();
        var isStaff = User.IsInRole(RoleNames.Admin) || User.IsInRole(RoleNames.SalonStaff);

        try
        {
            var reservation = await _service.GetByIdAsync(id, requestingUserId: userId, isStaff: isStaff);
            if (reservation == null)
                return NotFound();

            return reservation;
        }
        catch (Model.UserException)
        {
            return Forbid();
        }
    }

    // ── Customer ─────────────────────────────────────────────────────────────

    /// <summary>
    /// Returns the current customer's own rental reservations.
    /// </summary>
    [HttpGet("mine")]
    public async Task<ActionResult<PagedResult<RentalReservationResponse>>> GetMine(
        [FromQuery] RentalReservationSearchObject? search = null)
    {
        var customerId = User.GetUserId();
        return await _service.GetMineAsync(customerId, search ?? new RentalReservationSearchObject());
    }

    /// <summary>
    /// Creates a new rental reservation.
    /// The dress must be active and the requested period must be free of conflicts.
    /// </summary>
    [HttpPost]
    [Authorize(Roles = RoleNames.Customer)]
    public async Task<ActionResult<RentalReservationResponse>> Create(
        [FromBody] RentalReservationCreateRequest request)
    {
        var customerId = User.GetUserId();
        var created = await _service.CreateAsync(customerId, request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>
    /// Cancels a rental reservation.
    /// Customers can only cancel their own Pending reservations.
    /// Staff can cancel Pending or Approved reservations.
    /// </summary>
    [HttpPost("{id:int}/cancel")]
    public async Task<ActionResult<RentalReservationResponse>> Cancel(
        int id, [FromBody] RentalReservationCancelRequest? request = null)
    {
        var userId = User.GetUserId();
        var isStaff = User.IsInRole(RoleNames.Admin) || User.IsInRole(RoleNames.SalonStaff);
        return await _service.CancelAsync(id, userId, isStaff, request ?? new RentalReservationCancelRequest());
    }

    // ── Staff lifecycle ───────────────────────────────────────────────────────

    /// <summary>
    /// Approves a pending rental reservation (Pending → Approved).
    /// </summary>
    [HttpPost("{id:int}/approve")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RentalReservationResponse>> Approve(int id)
    {
        var staffUserId = User.GetUserId();
        return await _service.ApproveAsync(id, staffUserId);
    }

    /// <summary>
    /// Rejects a pending rental reservation (Pending → Rejected). Releases the availability hold.
    /// </summary>
    [HttpPost("{id:int}/reject")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RentalReservationResponse>> Reject(
        int id, [FromBody] RentalReservationStatusChangeRequest? request = null)
    {
        var staffUserId = User.GetUserId();
        return await _service.RejectAsync(id, staffUserId, request ?? new RentalReservationStatusChangeRequest());
    }

    /// <summary>
    /// Marks an approved reservation as ready for customer pickup (Approved → ReadyForPickup).
    /// </summary>
    [HttpPost("{id:int}/ready-for-pickup")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RentalReservationResponse>> ReadyForPickup(int id)
    {
        var staffUserId = User.GetUserId();
        return await _service.MarkReadyForPickupAsync(id, staffUserId);
    }

    /// <summary>
    /// Records that the customer has picked up the dress (ReadyForPickup → PickedUp).
    /// </summary>
    [HttpPost("{id:int}/picked-up")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RentalReservationResponse>> PickedUp(int id)
    {
        var staffUserId = User.GetUserId();
        return await _service.MarkPickedUpAsync(id, staffUserId);
    }

    /// <summary>
    /// Records the dress return (PickedUp → Returned). Accepts optional late and damage fees
    /// which are added to the total amount.
    /// </summary>
    [HttpPost("{id:int}/returned")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RentalReservationResponse>> Returned(
        int id, [FromBody] RentalReservationReturnRequest? request = null)
    {
        var staffUserId = User.GetUserId();
        return await _service.MarkReturnedAsync(id, staffUserId, request ?? new RentalReservationReturnRequest());
    }

    /// <summary>
    /// Completes the rental lifecycle (Returned → Completed).
    /// </summary>
    [HttpPost("{id:int}/complete")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RentalReservationResponse>> Complete(int id)
    {
        var staffUserId = User.GetUserId();
        return await _service.CompleteAsync(id, staffUserId);
    }

    /// <summary>
    /// Returns the full status history timeline for a reservation in chronological order.
    /// </summary>
    [HttpGet("{id:int}/timeline")]
    public async Task<ActionResult<List<RentalReservationStatusHistoryResponse>>> GetTimeline(int id)
    {
        return await _service.GetTimelineAsync(id);
    }
}
