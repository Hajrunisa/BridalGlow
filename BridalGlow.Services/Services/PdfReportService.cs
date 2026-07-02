using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using BridalGlow.Services.Reports;

namespace BridalGlow.Services.Services;

public class PdfReportService : IPdfReportService
{
    private readonly IReportingAggregationService _reportingService;

    public PdfReportService(IReportingAggregationService reportingService)
    {
        _reportingService = reportingService;
    }

    public async Task<byte[]> GenerateBusinessPerformancePdfAsync(ReportFilterSearchObject filter)
    {
        filter ??= new ReportFilterSearchObject();
        var dataset = await _reportingService.GetBusinessPerformanceReportAsync(filter);
        return BusinessPerformancePdfDocument.Generate(dataset);
    }

    public async Task<byte[]> GenerateFinancialPdfAsync(ReportFilterSearchObject filter)
    {
        filter ??= new ReportFilterSearchObject();
        var dataset = await _reportingService.GetFinancialReportAsync(filter);
        return FinancialReportPdfDocument.Generate(dataset);
    }
}
