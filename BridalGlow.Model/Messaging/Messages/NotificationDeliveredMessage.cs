using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Messaging.Messages;

/// <summary>
/// Published after a notification is persisted and marked Delivered; consumed by the API for SignalR push.
/// </summary>
public class NotificationDeliveredMessage
{
    public int NotificationId { get; set; }
    public int UserId { get; set; }
    public NotificationType Type { get; set; }
    public NotificationChannel Channel { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public NotificationStatus Status { get; set; }
    public string? RelatedEntityType { get; set; }
    public int? RelatedEntityId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime DeliveredAtUtc { get; set; }
}
