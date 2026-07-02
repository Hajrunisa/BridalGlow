using System.ComponentModel.DataAnnotations;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Requests;

public class UpdateDressConditionRequest
{
    [Required]
    public DressCondition Condition { get; set; }
}
