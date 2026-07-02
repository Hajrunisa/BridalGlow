using System.ComponentModel.DataAnnotations;

namespace BridalGlow.Model.Requests;

public class ReviewStaffReplyRequest
{
    [Required(ErrorMessage = "Odgovor osoblja je obavezan.")]
    [MaxLength(1000, ErrorMessage = "Odgovor ne smije biti duži od 1000 znakova.")]
    public string StaffReply { get; set; } = string.Empty;
}
