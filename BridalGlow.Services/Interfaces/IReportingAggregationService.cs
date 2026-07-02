using System.Threading.Tasks;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IReportingAggregationService
{
    Task<KpiSummaryResponse> GetKpiSummaryAsync(ReportFilterSearchObject filter);
    Task<BusinessPerformanceReportResponse> GetBusinessPerformanceReportAsync(ReportFilterSearchObject filter);
    Task<FinancialReportResponse> GetFinancialReportAsync(ReportFilterSearchObject filter);
}
