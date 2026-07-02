using System;
using System.Collections.Generic;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class MaintenanceSummaryResponse
{
    public int DressId { get; set; }
    public string DressName { get; set; } = string.Empty;
    public string DressCode { get; set; } = string.Empty;

    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }

    public int TotalRecordCount { get; set; }
    public decimal TotalCostAmount { get; set; }

    public List<MaintenanceTypeSummary> ByType { get; set; } = new();
}

public class MaintenanceTypeSummary
{
    public MaintenanceType MaintenanceType { get; set; }
    public string MaintenanceTypeLabel { get; set; } = string.Empty;
    public int RecordCount { get; set; }
    public decimal TotalCostAmount { get; set; }
}
