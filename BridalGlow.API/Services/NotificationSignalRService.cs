using BridalGlow.API.Hubs;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SignalR;
using Microsoft.AspNetCore.SignalR;

namespace BridalGlow.API.Services;

public class NotificationSignalRService : INotificationSignalRService
{
    private readonly IHubContext<NotificationHub> _hubContext;

    public NotificationSignalRService(IHubContext<NotificationHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public async Task PushAsync(NotificationDeliveredMessage message, CancellationToken cancellationToken = default)
    {
        var payload = MapToResponse(message);

        await _hubContext.Clients
            .Group(NotificationHubGroups.User(message.UserId))
            .SendAsync(NotificationHubMethods.ReceiveNotification, payload, cancellationToken);
    }

    private static NotificationResponse MapToResponse(NotificationDeliveredMessage message) => new()
    {
        Id = message.NotificationId,
        UserId = message.UserId,
        Type = message.Type,
        TypeLabel = message.Type.ToString(),
        Channel = message.Channel,
        Title = message.Title,
        Body = message.Body,
        Status = message.Status,
        StatusLabel = message.Status.ToString(),
        IsRead = message.Status == BridalGlow.Model.Enums.NotificationStatus.Read,
        RelatedEntityType = message.RelatedEntityType,
        RelatedEntityId = message.RelatedEntityId,
        CreatedAtUtc = message.CreatedAtUtc
    };
}
