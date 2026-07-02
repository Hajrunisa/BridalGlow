using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IPdfReportService
{
    Task<byte[]> GenerateBusinessPerformancePdfAsync(ReportFilterSearchObject filter);
    Task<byte[]> GenerateFinancialPdfAsync(ReportFilterSearchObject filter);
}
