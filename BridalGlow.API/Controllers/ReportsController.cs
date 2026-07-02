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
public class ReportsController : ControllerBase
{
    private readonly IReportingAggregationService _reportingService;
    private readonly IPdfReportService _pdfReportService;

    public ReportsController(
        IReportingAggregationService reportingService,
        IPdfReportService pdfReportService)
    {
        _reportingService = reportingService;
        _pdfReportService = pdfReportService;
    }

    /// <summary>
    /// Returns aggregated KPI metrics for finance, rentals, reviews, maintenance and dress portfolio.
    /// </summary>
    [HttpGet("kpi-summary")]
    public async Task<ActionResult<KpiSummaryResponse>> GetKpiSummary(
        [FromQuery] ReportFilterSearchObject? filter = null)
    {
        return await _reportingService.GetKpiSummaryAsync(filter ?? new ReportFilterSearchObject());
    }

    /// <summary>
    /// Returns the business performance report dataset with section details and monthly trends.
    /// </summary>
    [HttpGet("business-performance/dataset")]
    public async Task<ActionResult<BusinessPerformanceReportResponse>> GetBusinessPerformanceDataset(
        [FromQuery] ReportFilterSearchObject? filter = null)
    {
        return await _reportingService.GetBusinessPerformanceReportAsync(filter ?? new ReportFilterSearchObject());
    }

    /// <summary>
    /// Returns the financial report dataset with period summary, ledger entries and refund aggregates.
    /// </summary>
    [HttpGet("financial/dataset")]
    public async Task<ActionResult<FinancialReportResponse>> GetFinancialDataset(
        [FromQuery] ReportFilterSearchObject? filter = null)
    {
        return await _reportingService.GetFinancialReportAsync(filter ?? new ReportFilterSearchObject());
    }

    /// <summary>
    /// Generates the business performance report as a PDF document.
    /// </summary>
    [HttpGet("business-performance/pdf")]
    public async Task<IActionResult> GetBusinessPerformancePdf(
        [FromQuery] ReportFilterSearchObject? filter = null)
    {
        var pdfBytes = await _pdfReportService.GenerateBusinessPerformancePdfAsync(
            filter ?? new ReportFilterSearchObject());

        var fileName = $"BridalGlow_BusinessPerformance_{DateTime.UtcNow:yyyyMMdd_HHmm}.pdf";
        return File(pdfBytes, "application/pdf", fileName);
    }

    /// <summary>
    /// Generates the financial activity report as a PDF document.
    /// </summary>
    [HttpGet("financial/pdf")]
    public async Task<IActionResult> GetFinancialPdf(
        [FromQuery] ReportFilterSearchObject? filter = null)
    {
        var pdfBytes = await _pdfReportService.GenerateFinancialPdfAsync(
            filter ?? new ReportFilterSearchObject());

        var fileName = $"BridalGlow_Financial_{DateTime.UtcNow:yyyyMMdd_HHmm}.pdf";
        return File(pdfBytes, "application/pdf", fileName);
    }
}
