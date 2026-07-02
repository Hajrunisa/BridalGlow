using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class DressImageReorderRequest
{
    [Range(0, int.MaxValue, ErrorMessage = "Redoslijed mora biti veći ili jednak 0.")]
    public int SortOrder { get; set; }
}
