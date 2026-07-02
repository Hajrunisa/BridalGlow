using System.ComponentModel.DataAnnotations;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Requests;

public class InteractionIngestRequest
{
    [Required(ErrorMessage = "Identifikator vjenčanice je obavezan.")]
    [Range(1, int.MaxValue, ErrorMessage = "Identifikator vjenčanice mora biti veći od 0.")]
    public int DressId { get; set; }

    [Required(ErrorMessage = "Tip interakcije je obavezan.")]
    public InteractionType InteractionType { get; set; }

    [MaxLength(100, ErrorMessage = "SessionId ne smije biti duži od 100 znakova.")]
    public string? SessionId { get; set; }

    public string? MetadataJson { get; set; }
}
