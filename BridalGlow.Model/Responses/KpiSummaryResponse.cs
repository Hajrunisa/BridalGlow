using System;
using System.Collections.Generic;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class KpiSummaryResponse
{
    public DateTime? FromUtc { get; set; }
    public DateTime? ToUtc { get; set; }
    public int? DressId { get; set; }
    public int? DressCategoryId { get; set; }

    public FinanceKpiSection Finance { get; set; } = new();
    public RentalKpiSection Rentals { get; set; } = new();
    public ReviewKpiSection Reviews { get; set; } = new();
    public MaintenanceKpiSection Maintenance { get; set; } = new();
    public DressPortfolioKpiSection DressPortfolio { get; set; } = new();
}

public class FinanceKpiSection
{
    public decimal TotalCapturedAmount { get; set; }
    public decimal TotalRefundAmount { get; set; }
    public decimal NetRevenue { get; set; }
    public int TransactionCount { get; set; }
    public string Currency { get; set; } = "EUR";
}

public class RentalKpiSection
{
    public int TotalCount { get; set; }
    public decimal CompletionRate { get; set; }
    public decimal CancellationRate { get; set; }
    public List<RentalStatusCountItem> StatusBreakdown { get; set; } = new();
}

public class RentalStatusCountItem
{
    public RentalReservationStatus Status { get; set; }
    public string StatusLabel { get; set; } = string.Empty;
    public int Count { get; set; }
}

public class ReviewKpiSection
{
    public decimal AverageRating { get; set; }
    public int TotalCount { get; set; }
    public int PendingModerationCount { get; set; }
    public int PublishedCount { get; set; }
    public int HiddenCount { get; set; }
    public int RejectedCount { get; set; }
}

public class MaintenanceKpiSection
{
    public int TotalRecordCount { get; set; }
    public decimal TotalCostAmount { get; set; }
}

public class DressPortfolioKpiSection
{
    public int ActiveDressCount { get; set; }
    public int OutOfServiceDressCount { get; set; }
    public List<TopDressRentalItem> TopRentedDresses { get; set; } = new();
}

public class TopDressRentalItem
{
    public int DressId { get; set; }
    public string DressCode { get; set; } = string.Empty;
    public string DressName { get; set; } = string.Empty;
    public int RentalCount { get; set; }
}
