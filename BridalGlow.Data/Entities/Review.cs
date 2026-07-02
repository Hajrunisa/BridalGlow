using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class Review : AuditableEntity
{
    public int DressId { get; set; }
    public int CustomerUserId { get; set; }
    public int? RentalReservationId { get; set; }
    public int Rating { get; set; }
    public string? Title { get; set; }
    public string? Comment { get; set; }
    public ReviewStatus Status { get; set; }
    public string? ModerationNote { get; set; }
    public string? StaffReply { get; set; }
    public DateTime? PublishedAtUtc { get; set; }
    public DateTime? HiddenAtUtc { get; set; }

    public Dress Dress { get; set; } = null!;
    public User Customer { get; set; } = null!;
    public RentalReservation? RentalReservation { get; set; }
}
