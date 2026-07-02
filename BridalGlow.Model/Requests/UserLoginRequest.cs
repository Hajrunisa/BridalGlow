using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class UserLoginRequest
{
    [Required]
    public string Username { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}
