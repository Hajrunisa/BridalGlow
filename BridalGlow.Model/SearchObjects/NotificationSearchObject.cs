using System;

namespace BridalGlow.Model.SearchObjects;

public class NotificationSearchObject : BaseSearchObject
{
    public bool? IsRead { get; set; }
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
}
