using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Model.Responses;

namespace BridalGlow.API.Services;

public interface INotificationSignalRService
{
    Task PushAsync(NotificationDeliveredMessage message, CancellationToken cancellationToken = default);
}
