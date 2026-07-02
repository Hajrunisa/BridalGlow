namespace BridalGlow.Data.Entities;

public class DressSimilarity
{
    public int Id { get; set; }
    public int DressId { get; set; }
    public int SimilarDressId { get; set; }
    public decimal Score { get; set; }
    public string ModelVersion { get; set; } = string.Empty;
    public DateTime CalculatedAtUtc { get; set; }

    public Dress Dress { get; set; } = null!;
    public Dress SimilarDress { get; set; } = null!;
}
