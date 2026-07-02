using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class Notification : AuditableEntity
{
    public int UserId { get; set; }
    public NotificationType Type { get; set; }
    public NotificationChannel Channel { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public string? PayloadJson { get; set; }
    public NotificationStatus Status { get; set; }
    public DateTime? SentAtUtc { get; set; }
    public DateTime? ReadAtUtc { get; set; }
    public string? RelatedEntityType { get; set; }
    public int? RelatedEntityId { get; set; }

    public User User { get; set; } = null!;
}
