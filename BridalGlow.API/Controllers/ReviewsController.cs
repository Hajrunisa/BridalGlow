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
[Route("api/Reviews")]
public class ReviewsController : ControllerBase
{
    private readonly IReviewService _service;

    public ReviewsController(IReviewService service)
    {
        _service = service;
    }

    // ── Public: Published reviews for a dress ─────────────────────────────────

    /// <summary>
    /// Returns Published reviews for a specific dress. Accessible by anyone.
    /// Requires dressId query parameter.
    /// </summary>
    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<PagedResult<ReviewResponse>>> GetPublishedByDress(
        [FromQuery] int dressId,
        [FromQuery] ReviewSearchObject? search = null)
    {
        if (dressId <= 0)
            return BadRequest(new { errors = new { dressId = new[] { "dressId je obavezan parametar." } } });

        return await _service.GetPublishedByDressAsync(dressId, search ?? new ReviewSearchObject());
    }

    // ── Customer ─────────────────────────────────────────────────────────────

    /// <summary>
    /// Returns the authenticated customer's own reviews.
    /// </summary>
    [HttpGet("mine")]
    [Authorize]
    public async Task<ActionResult<PagedResult<ReviewResponse>>> GetMine(
        [FromQuery] ReviewSearchObject? search = null)
    {
        var customerId = User.GetUserId();
        return await _service.GetMineAsync(customerId, search ?? new ReviewSearchObject());
    }

    /// <summary>
    /// Customer submits a review for a completed rental reservation.
    /// One review per reservation; reservation must be Completed and owned by the customer.
    /// </summary>
    [HttpPost]
    [Authorize(Roles = RoleNames.Customer)]
    public async Task<ActionResult<ReviewResponse>> Create([FromBody] ReviewCreateRequest request)
    {
        var customerId = User.GetUserId();
        var created = await _service.CreateAsync(customerId, request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>
    /// Customer updates their own review. Only allowed while status is PendingModeration.
    /// </summary>
    [HttpPut("{id:int}")]
    [Authorize(Roles = RoleNames.Customer)]
    public async Task<ActionResult<ReviewResponse>> Update(int id, [FromBody] ReviewUpdateRequest request)
    {
        var customerId = User.GetUserId();
        var updated = await _service.UpdateAsync(id, customerId, request);
        return updated;
    }

    // ── Staff / Admin ─────────────────────────────────────────────────────────

    /// <summary>
    /// Staff/Admin view all reviews with full filters (status, dressId, rating, customerUserId).
    /// </summary>
    [HttpGet("all")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<PagedResult<ReviewResponse>>> GetAll(
        [FromQuery] ReviewSearchObject? search = null)
    {
        return await _service.GetAllAsync(search ?? new ReviewSearchObject());
    }

    // ── Moderation (Staff / Admin) ────────────────────────────────────────────

    /// <summary>
    /// Publishes a PendingModeration review (PendingModeration → Published).
    /// Recalculates Dress.AverageRating and Dress.RatingCount.
    /// Creates a ReviewSubmitted interaction and notifies the customer.
    /// </summary>
    [HttpPost("{id:int}/publish")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<ReviewResponse>> Publish(int id)
    {
        var staffUserId = User.GetUserId();
        return await _service.PublishAsync(id, staffUserId);
    }

    /// <summary>
    /// Hides a Published review (Published → Hidden).
    /// Recalculates Dress.AverageRating and Dress.RatingCount.
    /// Notifies the customer.
    /// </summary>
    [HttpPost("{id:int}/hide")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<ReviewResponse>> Hide(int id)
    {
        var staffUserId = User.GetUserId();
        return await _service.HideAsync(id, staffUserId);
    }

    /// <summary>
    /// Rejects a PendingModeration review (PendingModeration → Rejected).
    /// An optional ModerationNote can be provided which is included in the customer notification.
    /// </summary>
    [HttpPost("{id:int}/reject")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<ReviewResponse>> Reject(
        int id, [FromBody] ReviewModerationRequest? request = null)
    {
        var staffUserId = User.GetUserId();
        return await _service.RejectAsync(id, staffUserId, request ?? new ReviewModerationRequest());
    }

    /// <summary>
    /// Sets or updates the staff reply on a Published review.
    /// Only allowed when the review is in Published status.
    /// </summary>
    [HttpPut("{id:int}/staff-reply")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<ReviewResponse>> SetStaffReply(
        int id, [FromBody] ReviewStaffReplyRequest request)
    {
        var staffUserId = User.GetUserId();
        return await _service.SetStaffReplyAsync(id, staffUserId, request);
    }

    // ── Shared: get by ID ─────────────────────────────────────────────────────

    /// <summary>
    /// Returns a single review by ID.
    /// Staff/Admin can access any; customers can only access their own.
    /// </summary>
    [HttpGet("{id:int}")]
    [Authorize]
    public async Task<ActionResult<ReviewResponse>> GetById(int id)
    {
        var userId = User.GetUserId();
        var isStaff = User.IsInRole(RoleNames.Admin) || User.IsInRole(RoleNames.SalonStaff);

        try
        {
            var review = await _service.GetByIdAsync(id, requestingUserId: userId, isStaff: isStaff);
            if (review == null)
                return NotFound();

            return review;
        }
        catch (Model.UserException)
        {
            return Forbid();
        }
    }
}
