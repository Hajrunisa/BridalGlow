using BridalGlow.Model.Messaging;
using BridalGlow.Model.Messaging.Messages;

namespace BridalGlow.Services.Messaging;

public static class MessagingEventTypeResolver
{
    private static readonly Dictionary<Type, string> TypeToEventType = new()
    {
        [typeof(InfrastructurePingMessage)] = MessagingEventTypes.InfrastructurePing,
        [typeof(NotificationRequestedMessage)] = MessagingEventTypes.NotificationRequested,
        [typeof(SimilarityRecomputeRequestedMessage)] = MessagingEventTypes.RecommendationSimilarityRecomputeRequested,
        [typeof(SnapshotRecomputeRequestedMessage)] = MessagingEventTypes.RecommendationSnapshotRecomputeRequested
    };

    private static readonly Dictionary<string, Type> EventTypeToClrType = new()
    {
        [MessagingEventTypes.InfrastructurePing] = typeof(InfrastructurePingMessage),
        [MessagingEventTypes.NotificationRequested] = typeof(NotificationRequestedMessage),
        [MessagingEventTypes.RecommendationSimilarityRecomputeRequested] = typeof(SimilarityRecomputeRequestedMessage),
        [MessagingEventTypes.RecommendationSnapshotRecomputeRequested] = typeof(SnapshotRecomputeRequestedMessage)
    };

    public static string Resolve<TMessage>() => Resolve(typeof(TMessage));

    public static string Resolve(Type messageType)
    {
        if (TypeToEventType.TryGetValue(messageType, out var eventType))
            return eventType;

        throw new ArgumentException(
            $"Message type '{messageType.Name}' is not registered for outbox publishing.",
            nameof(messageType));
    }

    public static Type ResolveClrType(string eventType)
    {
        if (EventTypeToClrType.TryGetValue(eventType, out var clrType))
            return clrType;

        throw new ArgumentException(
            $"Event type '{eventType}' is not registered for outbox relay.",
            nameof(eventType));
    }
}
