using BridalGlow.Model.Responses;

namespace BridalGlow.Services.Interfaces;

/// <summary>
/// Dispatches a delivered notification to the real-time layer (RabbitMQ → API SignalR).
/// </summary>
public interface INotificationRealtimeDispatcher
{
    Task DispatchAsync(NotificationResponse notification, CancellationToken cancellationToken = default);
}
