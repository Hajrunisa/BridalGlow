using BridalGlow.Model.Enums;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Model.Responses;
using BridalGlow.Services.Interfaces;
using EasyNetQ;
using Microsoft.Extensions.Logging;

namespace BridalGlow.Services.Services;

public class RabbitMqNotificationRealtimeDispatcher : INotificationRealtimeDispatcher
{
    private readonly IBus _bus;
    private readonly ILogger<RabbitMqNotificationRealtimeDispatcher> _logger;

    public RabbitMqNotificationRealtimeDispatcher(
        IBus bus,
        ILogger<RabbitMqNotificationRealtimeDispatcher> logger)
    {
        _bus = bus;
        _logger = logger;
    }

    public async Task DispatchAsync(NotificationResponse notification, CancellationToken cancellationToken = default)
    {
        var message = new NotificationDeliveredMessage
        {
            NotificationId = notification.Id,
            UserId = notification.UserId,
            Type = notification.Type,
            Channel = notification.Channel,
            Title = notification.Title,
            Body = notification.Body,
            Status = notification.Status,
            RelatedEntityType = notification.RelatedEntityType,
            RelatedEntityId = notification.RelatedEntityId,
            CreatedAtUtc = notification.CreatedAtUtc,
            DeliveredAtUtc = DateTime.UtcNow
        };

        await _bus.PubSub.PublishAsync(message, cancellationToken);

        _logger.LogInformation(
            "Published realtime notification {NotificationId} for user {UserId}.",
            notification.Id,
            notification.UserId);
    }
}
