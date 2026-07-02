using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class DressPriceRuleResponse
{
    public int Id { get; set; }
    public int DressId { get; set; }
    public string DressName { get; set; } = string.Empty;
    public string DressCode { get; set; } = string.Empty;
    public PriceRuleType RuleType { get; set; }
    public string RuleTypeLabel { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public decimal? Percent { get; set; }
    public DateTime StartDateUtc { get; set; }
    public DateTime? EndDateUtc { get; set; }
    public int Priority { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}
