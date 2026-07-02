namespace BridalGlow.Data.Entities;

public class DressTag : AuditableEntity
{
    public string Name { get; set; } = string.Empty;

    public ICollection<DressTagMap> DressTagMaps { get; set; } = new List<DressTagMap>();
}
