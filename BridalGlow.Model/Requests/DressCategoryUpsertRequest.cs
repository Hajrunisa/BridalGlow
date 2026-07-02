using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class DressCategoryUpsertRequest
{
    [Required(ErrorMessage = "Naziv kategorije je obavezan.")]
    [MaxLength(100, ErrorMessage = "Naziv kategorije ne smije biti duži od 100 znakova.")]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500, ErrorMessage = "Opis ne smije biti duži od 500 znakova.")]
    public string? Description { get; set; }
}
