using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class PaymentStatusResponse
{
    public int PaymentId { get; set; }
    public PaymentStatus LocalStatus { get; set; }
    public string LocalStatusLabel { get; set; } = string.Empty;
    public string? StripeStatus { get; set; }
    public string? ProviderPaymentIntentId { get; set; }
    public RentalReservationStatus? RentalReservationStatus { get; set; }
    public string? RentalReservationStatusLabel { get; set; }
    public bool IsInSync { get; set; }
    public bool SyncApplied { get; set; }
    public PaymentResponse? Payment { get; set; }
}
