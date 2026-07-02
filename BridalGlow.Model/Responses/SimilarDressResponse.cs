namespace BridalGlow.Model.Responses;

public class SimilarDressResponse
{
    public DressListItemResponse Dress { get; set; } = new();

    public decimal Score { get; set; }

    public string? Reason { get; set; }
}
