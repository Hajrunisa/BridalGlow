using BridalGlow.Data.Database;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Model.Responses;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BridalGlow.Services.Services;

public class NotificationDeliveryService : INotificationDeliveryService
{
    private readonly INotificationService _notifications;
    private readonly BridalGlowDbContext _context;
    private readonly IEmailSenderService? _emailSender;
    private readonly INotificationRealtimeDispatcher? _realtimeDispatcher;
    private readonly ILogger<NotificationDeliveryService> _logger;

    public NotificationDeliveryService(
        INotificationService notifications,
        BridalGlowDbContext context,
        ILogger<NotificationDeliveryService> logger,
        IEmailSenderService? emailSender = null,
        INotificationRealtimeDispatcher? realtimeDispatcher = null)
    {
        _notifications = notifications;
        _context = context;
        _logger = logger;
        _emailSender = emailSender;
        _realtimeDispatcher = realtimeDispatcher;
    }

    public async Task ProcessAsync(NotificationRequestedMessage message, CancellationToken cancellationToken = default)
    {
        if (await _notifications.ExistsForDeliveryAsync(
                message.UserId,
                message.Type,
                message.RelatedEntityType,
                message.RelatedEntityId))
        {
            _logger.LogInformation(
                "Skipping duplicate notification for user {UserId}, type {Type}, entity {EntityType}/{EntityId}.",
                message.UserId,
                message.Type,
                message.RelatedEntityType,
                message.RelatedEntityId);
            return;
        }

        var created = await _notifications.TryCreateQueuedAsync(
            message.UserId,
            message.Title,
            message.Body,
            message.Type,
            message.Channel,
            message.RelatedEntityType,
            message.RelatedEntityId);

        if (created == null)
        {
            _logger.LogInformation(
                "Notification already exists for user {UserId}, type {Type}.",
                message.UserId,
                message.Type);
            return;
        }

        var emailFailed = false;
        string? emailError = null;

        if (message.SendEmail && _emailSender != null)
        {
            var user = await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == message.UserId && !u.IsDeleted, cancellationToken);

            if (user != null && !string.IsNullOrWhiteSpace(user.Email))
            {
                try
                {
                    await _emailSender.SendPlainTextAsync(user.Email, message.Title, message.Body);
                    await _notifications.SetDeliveryStatusAsync(created.Id, NotificationStatus.Sent);
                    _logger.LogInformation(
                        "Email sent for notification {NotificationId} to {Email}.",
                        created.Id,
                        user.Email);
                }
                catch (Exception ex)
                {
                    emailFailed = true;
                    emailError = ex.Message;
                    _logger.LogWarning(
                        ex,
                        "Email delivery failed for notification {NotificationId}.",
                        created.Id);
                }
            }
            else
            {
                emailFailed = true;
                emailError = "User email not found.";
                _logger.LogWarning(
                    "Cannot send email for notification {NotificationId}: user {UserId} has no email.",
                    created.Id,
                    message.UserId);
            }
        }

        if (message.Channel == NotificationChannel.Email && emailFailed)
        {
            await _notifications.SetDeliveryStatusAsync(
                created.Id,
                NotificationStatus.Failed,
                emailError);
            return;
        }

        await _notifications.SetDeliveryStatusAsync(created.Id, NotificationStatus.Delivered);

        if (emailFailed && emailError != null)
            _logger.LogInformation(
                "In-app notification {NotificationId} delivered; email was not sent.",
                created.Id);

        await TryDispatchRealtimeAsync(created);
    }

    private async Task TryDispatchRealtimeAsync(NotificationResponse notification)
    {
        if (_realtimeDispatcher == null)
            return;

        try
        {
            await _realtimeDispatcher.DispatchAsync(notification);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                ex,
                "Realtime dispatch failed for notification {NotificationId}; DB delivery succeeded.",
                notification.Id);
        }
    }
}
