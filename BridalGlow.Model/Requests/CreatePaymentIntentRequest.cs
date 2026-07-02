using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class CreatePaymentIntentRequest
{
    [Required]
    [Range(1, int.MaxValue, ErrorMessage = "RentalReservationId je obavezan.")]
    public int RentalReservationId { get; set; }
}
