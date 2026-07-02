using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.SearchObjects;

public class PaymentSearchObject : BaseSearchObject
{
    public int? CustomerUserId { get; set; }
    public int? RentalReservationId { get; set; }
    public PaymentStatus? Status { get; set; }
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
    public decimal? MinAmount { get; set; }
    public decimal? MaxAmount { get; set; }
}
