using BridalGlow.Data.Entities;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IFinancialLedgerService
{
    Task RecordPaymentCaptureAsync(Payment payment, string? reservationNumber = null);
    Task RecordRefundAsync(Refund refund, Payment payment, string? reservationNumber = null);
    Task<LedgerReportResponse> GetLedgerAsync(DateTime? fromUtc, DateTime? toUtc);
}
