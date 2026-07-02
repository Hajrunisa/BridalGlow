using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class RefreshTokenRequest
{
    [Required]
    public string RefreshToken { get; set; } = string.Empty;
}
