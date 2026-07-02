using BridalGlow.Model.Enums;

namespace BridalGlow.Services.Interfaces;

/// <summary>
/// Stages user notification requests into the transactional outbox for worker delivery.
/// </summary>
public interface IDomainNotificationPublisher
{
    void StageCustomerNotification(
        int userId,
        string title,
        string body,
        NotificationType type,
        string? relatedEntityType = null,
        int? relatedEntityId = null);

    Task StageStaffOperationalNotificationsAsync(
        string title,
        string body,
        NotificationType type,
        string? relatedEntityType = null,
        int? relatedEntityId = null,
        CancellationToken cancellationToken = default);
}
