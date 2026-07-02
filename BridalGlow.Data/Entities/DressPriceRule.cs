using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class DressPriceRule : AuditableEntity
{
    public int DressId { get; set; }
    public PriceRuleType RuleType { get; set; }
    public decimal Amount { get; set; }
    public decimal? Percent { get; set; }
    public DateTime StartDateUtc { get; set; }
    public DateTime? EndDateUtc { get; set; }
    public int Priority { get; set; }
    public bool IsActive { get; set; } = true;

    public Dress Dress { get; set; } = null!;
}
