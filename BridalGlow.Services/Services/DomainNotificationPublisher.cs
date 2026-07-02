using BridalGlow.Data.Database;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public class DomainNotificationPublisher : IDomainNotificationPublisher
{
    private readonly IDomainEventPublisher _eventPublisher;
    private readonly BridalGlowDbContext _context;

    public DomainNotificationPublisher(
        IDomainEventPublisher eventPublisher,
        BridalGlowDbContext context)
    {
        _eventPublisher = eventPublisher;
        _context = context;
    }

    public void StageCustomerNotification(
        int userId,
        string title,
        string body,
        NotificationType type,
        string? relatedEntityType = null,
        int? relatedEntityId = null)
    {
        _eventPublisher.Stage(BuildMessage(userId, title, body, type, relatedEntityType, relatedEntityId));
    }

    public async Task StageStaffOperationalNotificationsAsync(
        string title,
        string body,
        NotificationType type,
        string? relatedEntityType = null,
        int? relatedEntityId = null,
        CancellationToken cancellationToken = default)
    {
        var staffUserIds = await _context.Users
            .AsNoTracking()
            .Where(u => !u.IsDeleted
                     && u.IsActive
                     && (u.Role == UserRole.Admin || u.Role == UserRole.SalonStaff))
            .Select(u => u.Id)
            .ToListAsync(cancellationToken);

        foreach (var staffUserId in staffUserIds)
        {
            _eventPublisher.Stage(BuildMessage(
                staffUserId,
                title,
                body,
                type,
                relatedEntityType,
                relatedEntityId));
        }
    }

    private static NotificationRequestedMessage BuildMessage(
        int userId,
        string title,
        string body,
        NotificationType type,
        string? relatedEntityType,
        int? relatedEntityId)
    {
        return new NotificationRequestedMessage
        {
            UserId = userId,
            Title = title,
            Body = body,
            Type = type,
            Channel = NotificationChannel.InApp,
            RelatedEntityType = relatedEntityType,
            RelatedEntityId = relatedEntityId,
            SendEmail = false
        };
    }
}
