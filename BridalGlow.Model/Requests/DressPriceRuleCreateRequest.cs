using System;
using System.ComponentModel.DataAnnotations;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Requests;

public class DressPriceRuleCreateRequest
{
    [Required(ErrorMessage = "DressId je obavezan.")]
    [Range(1, int.MaxValue, ErrorMessage = "DressId mora biti veći od 0.")]
    public int DressId { get; set; }

    [Required(ErrorMessage = "Tip pravila je obavezan.")]
    public PriceRuleType RuleType { get; set; }

    [Range(0, (double)decimal.MaxValue, ErrorMessage = "Iznos mora biti veći ili jednak 0.")]
    public decimal Amount { get; set; }

    [Range(0.01, 100, ErrorMessage = "Procenat mora biti između 0.01 i 100.")]
    public decimal? Percent { get; set; }

    [Required(ErrorMessage = "Datum početka je obavezan.")]
    public DateTime StartDateUtc { get; set; }

    public DateTime? EndDateUtc { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Prioritet mora biti veći od 0.")]
    public int Priority { get; set; } = 1;

    public bool IsActive { get; set; } = true;
}
