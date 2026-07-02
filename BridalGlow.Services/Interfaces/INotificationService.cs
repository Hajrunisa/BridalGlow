using BridalGlow.Model.Enums;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface INotificationService
{
    /// <summary>
    /// Returns a paged list of notifications for the specified user with optional filtering.
    /// </summary>
    Task<PagedResult<NotificationResponse>> GetMyNotificationsAsync(int userId, NotificationSearchObject search);

    /// <summary>
    /// Marks a single notification as read. Throws if notification not found or belongs to a different user.
    /// </summary>
    Task<NotificationResponse> MarkAsReadAsync(int id, int userId);

    /// <summary>
    /// Marks all unread notifications for the specified user as read.
    /// </summary>
    Task MarkAllAsReadAsync(int userId);

    /// <summary>
    /// Creates and persists a new in-app notification for the specified user.
    /// Designed to be called from any service when a relevant domain event occurs.
    /// </summary>
    Task CreateAsync(
        int userId,
        string title,
        string body,
        NotificationType type,
        string? relatedEntityType = null,
        int? relatedEntityId = null);

    /// <summary>
    /// Returns true when an equivalent notification already exists (idempotent delivery guard).
    /// </summary>
    Task<bool> ExistsForDeliveryAsync(
        int userId,
        NotificationType type,
        string? relatedEntityType,
        int? relatedEntityId);

    /// <summary>
    /// Worker/async path: creates a notification in <see cref="NotificationStatus.Queued"/> state.
    /// Returns null when a duplicate exists.
    /// </summary>
    Task<NotificationResponse?> TryCreateQueuedAsync(
        int userId,
        string title,
        string body,
        NotificationType type,
        NotificationChannel channel,
        string? relatedEntityType = null,
        int? relatedEntityId = null);

    /// <summary>
    /// Updates delivery status for worker-managed notifications (Sent, Delivered, Failed).
    /// </summary>
    Task SetDeliveryStatusAsync(int notificationId, NotificationStatus status, string? error = null);
}
