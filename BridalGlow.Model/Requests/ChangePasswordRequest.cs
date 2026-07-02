using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class ChangePasswordRequest
{
    [Required]
    public string CurrentPassword { get; set; } = string.Empty;

    [Required]
    [MinLength(4)]
    public string NewPassword { get; set; } = string.Empty;
}
