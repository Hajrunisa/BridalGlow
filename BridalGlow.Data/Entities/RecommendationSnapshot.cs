namespace BridalGlow.Data.Entities;

public class RecommendationSnapshot
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int DressId { get; set; }
    public decimal Score { get; set; }
    public int Rank { get; set; }
    public string ModelVersion { get; set; } = string.Empty;
    public DateTime GeneratedAtUtc { get; set; }

    public User User { get; set; } = null!;
    public Dress Dress { get; set; } = null!;
}
