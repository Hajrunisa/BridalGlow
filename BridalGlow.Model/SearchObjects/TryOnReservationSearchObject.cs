using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.SearchObjects;

public class TryOnReservationSearchObject : BaseSearchObject
{
    public TryOnReservationStatus? Status { get; set; }
    public int? DressId { get; set; }
    public int? CustomerUserId { get; set; }
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
}
