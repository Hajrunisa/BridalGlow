using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class ReviewUpdateRequest
{
    [Range(1, 5, ErrorMessage = "Ocjena mora biti između 1 i 5.")]
    public int? Rating { get; set; }

    [MaxLength(200, ErrorMessage = "Naslov ne smije biti duži od 200 znakova.")]
    public string? Title { get; set; }

    [MaxLength(2000, ErrorMessage = "Komentar ne smije biti duži od 2000 znakova.")]
    public string? Comment { get; set; }
}
