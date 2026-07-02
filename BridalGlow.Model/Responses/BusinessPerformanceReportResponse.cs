using System;
using System.Collections.Generic;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class BusinessPerformanceReportResponse
{
    public DateTime? FromUtc { get; set; }
    public DateTime? ToUtc { get; set; }
    public int? DressId { get; set; }
    public int? DressCategoryId { get; set; }

    public FinanceKpiSection Finance { get; set; } = new();
    public RentalKpiSection Rentals { get; set; } = new();
    public BusinessReviewReportSection Reviews { get; set; } = new();
    public BusinessMaintenanceReportSection Maintenance { get; set; } = new();
    public DressPortfolioKpiSection DressPortfolio { get; set; } = new();
    public List<MonthlyTrendItem> MonthlyTrends { get; set; } = new();
}

public class BusinessReviewReportSection
{
    public ReviewKpiSection Summary { get; set; } = new();
    public List<ReviewRatingDistributionItem> RatingDistribution { get; set; } = new();
}

public class BusinessMaintenanceReportSection
{
    public MaintenanceKpiSection Summary { get; set; } = new();
    public List<MaintenanceTypeBreakdownItem> ByType { get; set; } = new();
}

public class MonthlyTrendItem
{
    public string Month { get; set; } = string.Empty;
    public decimal Revenue { get; set; }
    public int RentalCount { get; set; }
}

public class ReviewRatingDistributionItem
{
    public int Rating { get; set; }
    public int Count { get; set; }
}

public class MaintenanceTypeBreakdownItem
{
    public MaintenanceType MaintenanceType { get; set; }
    public string MaintenanceTypeLabel { get; set; } = string.Empty;
    public int RecordCount { get; set; }
    public decimal TotalCostAmount { get; set; }
}
