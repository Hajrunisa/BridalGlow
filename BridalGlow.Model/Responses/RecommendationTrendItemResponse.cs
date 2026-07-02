namespace BridalGlow.Model.Responses;

public class RecommendationTrendItemResponse
{
    public DressListItemResponse Dress { get; set; } = new();

    public int AppearanceCount { get; set; }

    public decimal TotalScore { get; set; }

    public int Rank { get; set; }
}
