namespace BridalGlow.Data.Entities;

public class DressCategory : AuditableEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }

    public ICollection<Dress> Dresses { get; set; } = new List<Dress>();
}
