using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class ReviewModerationRequest
{
    [MaxLength(500, ErrorMessage = "Napomena moderacije ne smije biti duža od 500 znakova.")]
    public string? ModerationNote { get; set; }
}
