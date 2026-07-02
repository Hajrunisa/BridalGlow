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
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _service;

    public PaymentsController(IPaymentService service)
    {
        _service = service;
    }

    /// <summary>
    /// Creates a Stripe PaymentIntent for an approved rental reservation.
    /// The reservation moves to AwaitingPayment and a Payment record is created with status Created.
    /// </summary>
    [HttpPost("create-intent")]
    [Authorize(Roles = RoleNames.Customer)]
    public async Task<ActionResult<PaymentIntentResponse>> CreatePaymentIntent(
        [FromBody] CreatePaymentIntentRequest request)
    {
        var customerId = User.GetUserId();
        return await _service.CreatePaymentIntentAsync(customerId, request);
    }

    /// <summary>
    /// Returns payments for the currently logged-in customer.
    /// </summary>
    [HttpGet("mine")]
    public async Task<ActionResult<PagedResult<PaymentResponse>>> GetMine(
        [FromQuery] PaymentSearchObject? search = null)
    {
        var customerId = User.GetUserId();
        return await _service.GetMineAsync(customerId, search ?? new PaymentSearchObject());
    }

    /// <summary>
    /// Returns a paged list of all payments. Accessible by Staff and Admin only.
    /// </summary>
    [HttpGet]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<PagedResult<PaymentResponse>>> GetAll(
        [FromQuery] PaymentSearchObject? search = null)
    {
        return await _service.GetAsync(search ?? new PaymentSearchObject());
    }

    /// <summary>
    /// Returns a single payment by ID.
    /// Staff/Admin can access any payment; customers can only access their own.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<PaymentResponse>> GetById(int id)
    {
        var userId = User.GetUserId();
        var isStaff = User.IsInRole(RoleNames.Admin) || User.IsInRole(RoleNames.SalonStaff);

        try
        {
            var payment = await _service.GetByIdAsync(id, requestingUserId: userId, isStaff: isStaff);
            if (payment == null)
                return NotFound();

            return payment;
        }
        catch (Model.UserException)
        {
            return Forbid();
        }
    }

    /// <summary>
    /// Returns the current local payment status and the live Stripe PaymentIntent status.
    /// Does not modify local state — use POST sync to apply changes from Stripe.
    /// </summary>
    [HttpGet("{id:int}/status")]
    public async Task<ActionResult<PaymentStatusResponse>> GetStatus(int id)
    {
        var userId = User.GetUserId();
        var isStaff = User.IsInRole(RoleNames.Admin) || User.IsInRole(RoleNames.SalonStaff);

        try
        {
            return await _service.GetStatusAsync(id, requestingUserId: userId, isStaff: isStaff);
        }
        catch (Model.UserException ex) when (ex.Message.Contains("nije pronađena"))
        {
            return NotFound();
        }
        catch (Model.UserException)
        {
            return Forbid();
        }
    }

    /// <summary>
    /// Synchronizes local payment and rental reservation state with Stripe.
    /// On success, moves the rental reservation to Paid and sends a notification.
    /// </summary>
    [HttpPost("{id:int}/sync")]
    public async Task<ActionResult<PaymentStatusResponse>> SyncStatus(int id)
    {
        var userId = User.GetUserId();
        var isStaff = User.IsInRole(RoleNames.Admin) || User.IsInRole(RoleNames.SalonStaff);

        try
        {
            return await _service.SyncStatusAsync(id, requestingUserId: userId, isStaff: isStaff);
        }
        catch (Model.UserException ex) when (ex.Message.Contains("nije pronađena"))
        {
            return NotFound();
        }
        catch (Model.UserException)
        {
            return Forbid();
        }
    }
}
