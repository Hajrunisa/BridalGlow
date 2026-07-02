using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.SearchObjects;

public class RefundSearchObject : BaseSearchObject
{
    public int? PaymentId { get; set; }
    public int? RequestedByUserId { get; set; }
    public RefundStatus? Status { get; set; }
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
}
