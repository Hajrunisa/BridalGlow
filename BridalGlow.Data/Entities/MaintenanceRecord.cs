using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class MaintenanceRecord : AuditableEntity
{
    public int DressId { get; set; }
    public int RecordedByUserId { get; set; }
    public MaintenanceType MaintenanceType { get; set; }
    public MaintenanceStatus Status { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal CostAmount { get; set; }
    public DateTime PerformedAtUtc { get; set; }
    public DateTime? NextCheckAtUtc { get; set; }
    public string? VendorName { get; set; }
    public string? InvoiceNumber { get; set; }
    public DressCondition? BeforeCondition { get; set; }
    public DressCondition? AfterCondition { get; set; }
    public DateTime? OutOfServiceFromUtc { get; set; }
    public DateTime? OutOfServiceToUtc { get; set; }

    public Dress Dress { get; set; } = null!;
    public User RecordedByUser { get; set; } = null!;
}
