using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class EffectivePriceResponse
{
    public int DressId { get; set; }
    public DateTime StartAt { get; set; }
    public DateTime EndAt { get; set; }
    public decimal BaseRentalPrice { get; set; }
    public decimal EffectivePrice { get; set; }

    /// <summary>
    /// The applied rule, or null if base price was used.
    /// </summary>
    public DressPriceRuleResponse? AppliedRule { get; set; }
}
