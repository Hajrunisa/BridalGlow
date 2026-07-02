using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Messaging.Messages;

/// <summary>
/// Request to create and deliver a user notification via the worker pipeline.
/// </summary>
public class NotificationRequestedMessage
{
    public int UserId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public NotificationType Type { get; set; }
    public NotificationChannel Channel { get; set; } = NotificationChannel.InApp;
    public string? RelatedEntityType { get; set; }
    public int? RelatedEntityId { get; set; }
    public bool SendEmail { get; set; }
}
