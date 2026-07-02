using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class DressImageLinkRequest
{
    [Required(ErrorMessage = "ID vjenčanice je obavezan.")]
    [Range(1, int.MaxValue, ErrorMessage = "ID vjenčanice mora biti veći od 0.")]
    public int DressId { get; set; }

    [Required(ErrorMessage = "URL slike je obavezan.")]
    [MaxLength(1000, ErrorMessage = "URL ne smije biti duži od 1000 znakova.")]
    [Url(ErrorMessage = "URL nije ispravan.")]
    public string Url { get; set; } = string.Empty;

    [MaxLength(200, ErrorMessage = "Alternativni tekst ne smije biti duži od 200 znakova.")]
    public string? AltText { get; set; }

    public int SortOrder { get; set; }

    public bool IsPrimary { get; set; }
}
