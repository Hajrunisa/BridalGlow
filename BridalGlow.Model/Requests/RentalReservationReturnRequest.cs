namespace BridalGlow.Model.Requests;

public class RentalReservationReturnRequest
{
    public decimal? LateFeeAmount { get; set; }
    public decimal? DamageFeeAmount { get; set; }
    public string? Notes { get; set; }
}
