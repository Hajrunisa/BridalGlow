using BridalGlow.Model.Enums;

namespace BridalGlow.Model.SearchObjects;

public class DressPriceRuleSearchObject : BaseSearchObject
{
    public int? DressId { get; set; }
    public PriceRuleType? RuleType { get; set; }
    public bool? IsActive { get; set; }
}
