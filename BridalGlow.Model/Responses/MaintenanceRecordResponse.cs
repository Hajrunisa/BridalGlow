using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class MaintenanceRecordResponse
{
    public int Id { get; set; }

    public int DressId { get; set; }
    public string DressName { get; set; } = string.Empty;
    public string DressCode { get; set; } = string.Empty;

    public int RecordedByUserId { get; set; }
    public string RecordedByUserName { get; set; } = string.Empty;

    public MaintenanceType MaintenanceType { get; set; }
    public string MaintenanceTypeLabel { get; set; } = string.Empty;

    public MaintenanceStatus Status { get; set; }
    public string StatusLabel { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;
    public decimal CostAmount { get; set; }

    public string? VendorName { get; set; }
    public string? InvoiceNumber { get; set; }

    public DressCondition? BeforeCondition { get; set; }
    public string? BeforeConditionLabel { get; set; }

    public DressCondition? AfterCondition { get; set; }
    public string? AfterConditionLabel { get; set; }

    public DateTime? OutOfServiceFromUtc { get; set; }
    public DateTime? OutOfServiceToUtc { get; set; }

    public DateTime PerformedAtUtc { get; set; }
    public DateTime? NextCheckAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}
