using System;

namespace BridalGlow.Model.SearchObjects;

public class ReportFilterSearchObject
{
    public DateTime? FromUtc { get; set; }
    public DateTime? ToUtc { get; set; }
    public int? DressId { get; set; }
    public int? DressCategoryId { get; set; }
}
