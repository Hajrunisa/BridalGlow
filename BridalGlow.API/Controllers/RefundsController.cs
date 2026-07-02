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
[Route("api/[controller]")]
[Authorize]
public class RefundsController : ControllerBase
{
    private readonly IRefundService _service;

    public RefundsController(IRefundService service)
    {
        _service = service;
    }

    /// <summary>
    /// Creates a refund request for a successful payment.
    /// Customers can request refunds for their own payments; staff can request for any payment.
    /// </summary>
    [HttpPost("request")]
    public async Task<ActionResult<RefundResponse>> SubmitRequest(
        [FromBody] RefundRequestCreateRequest request)
    {
        var userId = User.GetUserId();
        var isStaff = User.IsInRole(RoleNames.Admin) || User.IsInRole(RoleNames.SalonStaff);
        return await _service.RequestAsync(userId, isStaff, request);
    }

    /// <summary>
    /// Approves a pending refund request (Requested → Approved).
    /// </summary>
    [HttpPost("{id:int}/approve")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RefundResponse>> Approve(int id)
    {
        var staffUserId = User.GetUserId();
        return await _service.ApproveAsync(id, staffUserId);
    }

    /// <summary>
    /// Rejects a pending refund request (Requested → Rejected).
    /// </summary>
    [HttpPost("{id:int}/reject")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RefundResponse>> Reject(
        int id, [FromBody] RefundRejectRequest? request = null)
    {
        var staffUserId = User.GetUserId();
        return await _service.RejectAsync(id, staffUserId, request ?? new RefundRejectRequest());
    }

    /// <summary>
    /// Processes an approved refund via Stripe Refund API (Approved → Processing → Succeeded/Failed).
    /// </summary>
    [HttpPost("{id:int}/process")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RefundResponse>> Process(int id)
    {
        var staffUserId = User.GetUserId();
        return await _service.ProcessAsync(id, staffUserId);
    }

    /// <summary>
    /// Returns refund requests for the currently logged-in customer.
    /// </summary>
    [HttpGet("mine")]
    public async Task<ActionResult<PagedResult<RefundResponse>>> GetMine(
        [FromQuery] RefundSearchObject? search = null)
    {
        var customerId = User.GetUserId();
        return await _service.GetMineAsync(customerId, search ?? new RefundSearchObject());
    }

    /// <summary>
    /// Returns a paged list of all refund requests. Accessible by Staff and Admin only.
    /// </summary>
    [HttpGet]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<PagedResult<RefundResponse>>> GetAll(
        [FromQuery] RefundSearchObject? search = null)
    {
        return await _service.GetAsync(search ?? new RefundSearchObject());
    }
}
