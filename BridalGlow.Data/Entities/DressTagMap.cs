namespace BridalGlow.Data.Entities;

public class DressTagMap : AuditableEntity
{
    public int DressId { get; set; }
    public int DressTagId { get; set; }

    public Dress Dress { get; set; } = null!;
    public DressTag DressTag { get; set; } = null!;
}
