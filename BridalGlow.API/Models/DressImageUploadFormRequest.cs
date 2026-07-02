using System.ComponentModel.DataAnnotations;

namespace BridalGlow.API.Models;

/// <summary>
/// multipart/form-data model for the dress-image upload endpoint.
/// Defined in the API project because IFormFile is an ASP.NET Core type
/// unavailable in the netstandard2.1 Model project.
/// </summary>
public class DressImageUploadFormRequest
{
    [Required(ErrorMessage = "ID vjenčanice je obavezan.")]
    [Range(1, int.MaxValue, ErrorMessage = "ID vjenčanice mora biti veći od 0.")]
    public int DressId { get; set; }

    [Required(ErrorMessage = "Fajl je obavezan.")]
    public IFormFile File { get; set; } = null!;

    [MaxLength(200, ErrorMessage = "Alternativni tekst ne smije biti duži od 200 znakova.")]
    public string? AltText { get; set; }

    public bool IsPrimary { get; set; }

    public int SortOrder { get; set; }
}
