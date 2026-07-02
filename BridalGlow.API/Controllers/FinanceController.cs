using BridalGlow.Model.Constants;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = RoleNames.AdminOrStaff)]
public class FinanceController : ControllerBase
{
    private readonly IFinancialLedgerService _ledgerService;
    private readonly IPaymentService _paymentService;
    private readonly IRefundService _refundService;

    public FinanceController(
        IFinancialLedgerService ledgerService,
        IPaymentService paymentService,
        IRefundService refundService)
    {
        _ledgerService = ledgerService;
        _paymentService = paymentService;
        _refundService = refundService;
    }

    /// <summary>
    /// Returns a paged list of payments for finance tracking.
    /// </summary>
    [HttpGet("payments")]
    public async Task<ActionResult<PagedResult<PaymentResponse>>> GetPayments(
        [FromQuery] PaymentSearchObject? search = null)
    {
        return await _paymentService.GetAsync(search ?? new PaymentSearchObject());
    }

    /// <summary>
    /// Returns a paged list of refunds for finance tracking.
    /// </summary>
    [HttpGet("refunds")]
    public async Task<ActionResult<PagedResult<RefundResponse>>> GetRefunds(
        [FromQuery] RefundSearchObject? search = null)
    {
        return await _refundService.GetAsync(search ?? new RefundSearchObject());
    }

    /// <summary>
    /// Returns ledger entries for the given period together with period aggregates.
    /// </summary>
    [HttpGet("ledger")]
    public async Task<ActionResult<LedgerReportResponse>> GetLedger(
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null)
    {
        return await _ledgerService.GetLedgerAsync(from, to);
    }
}
