using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class DressTagUpsertRequest
{
    [Required(ErrorMessage = "Naziv taga je obavezan.")]
    [MaxLength(100, ErrorMessage = "Naziv taga ne smije biti duži od 100 znakova.")]
    public string Name { get; set; } = string.Empty;
}
