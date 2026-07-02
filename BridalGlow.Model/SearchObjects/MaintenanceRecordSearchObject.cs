using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.SearchObjects;

public class MaintenanceRecordSearchObject : BaseSearchObject
{
    public int? DressId { get; set; }
    public MaintenanceStatus? Status { get; set; }
    public MaintenanceType? MaintenanceType { get; set; }
    public int? RecordedByUserId { get; set; }
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
}
