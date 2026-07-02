using BridalGlow.Model.Messaging.Messages;

namespace BridalGlow.Services.Interfaces;

public interface INotificationDeliveryService
{
    Task ProcessAsync(NotificationRequestedMessage message, CancellationToken cancellationToken = default);
}
