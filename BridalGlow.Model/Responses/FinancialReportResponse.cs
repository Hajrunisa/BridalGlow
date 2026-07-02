using System;
using System.Collections.Generic;

namespace BridalGlow.Model.Responses;

public class FinancialReportResponse
{
    public DateTime? FromUtc { get; set; }
    public DateTime? ToUtc { get; set; }
    public int? DressId { get; set; }
    public int? DressCategoryId { get; set; }

    public FinanceKpiSection PeriodSummary { get; set; } = new();
    public LedgerReportResponse Ledger { get; set; } = new();
    public RefundSummarySection Refunds { get; set; } = new();
}

public class RefundSummarySection
{
    public int TotalCount { get; set; }
    public decimal TotalSucceededAmount { get; set; }
    public int SucceededCount { get; set; }
    public int PendingCount { get; set; }
    public int RejectedCount { get; set; }
    public string Currency { get; set; } = "EUR";
}
