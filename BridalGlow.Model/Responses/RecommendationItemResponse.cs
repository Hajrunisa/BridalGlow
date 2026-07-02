namespace BridalGlow.Model.Responses;

public class RecommendationItemResponse
{
    public DressListItemResponse Dress { get; set; } = new();

    public decimal Score { get; set; }

    public int Rank { get; set; }

    public string Reason { get; set; } = string.Empty;
}
