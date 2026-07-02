namespace BridalGlow.Model.Messaging;

/// <summary>
/// Stable event type identifiers stored in <see cref="BridalGlow.Data.Entities.OutboxMessage.EventType"/>.
/// </summary>
public static class MessagingEventTypes
{
    public const string InfrastructurePing = "Infrastructure.Ping";
    public const string NotificationRequested = "Notification.Requested";
    public const string RecommendationSimilarityRecomputeRequested = "Recommendation.SimilarityRecomputeRequested";
    public const string RecommendationSnapshotRecomputeRequested = "Recommendation.SnapshotRecomputeRequested";
}
