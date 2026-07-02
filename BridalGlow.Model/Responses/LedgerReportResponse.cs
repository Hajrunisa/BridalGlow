using System;
using System.Collections.Generic;

namespace BridalGlow.Model.Responses;

public class LedgerPeriodSummary
{
    public decimal TotalReceivedAmount { get; set; }
    public int TransactionCount { get; set; }
    public string Currency { get; set; } = "EUR";
}

public class LedgerReportResponse
{
    public DateTime? FromUtc { get; set; }
    public DateTime? ToUtc { get; set; }
    public LedgerPeriodSummary Summary { get; set; } = new();
    public List<TransactionLedgerEntryResponse> Entries { get; set; } = new();
}
