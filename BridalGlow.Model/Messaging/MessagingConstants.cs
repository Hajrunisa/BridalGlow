namespace BridalGlow.Model.Messaging;

/// <summary>
/// RabbitMQ / EasyNetQ subscription identifiers for pub/sub routing.
/// </summary>
public static class MessagingConstants
{
    public const string InfrastructureSubscriptionId = "BridalGlow_Infrastructure";
    public const string NotificationSubscriptionId = "BridalGlow_Notifications";
    public const string NotificationPushSubscriptionId = "BridalGlow_NotificationPush";
    public const string SimilarityRecomputeSubscriptionId = "BridalGlow_SimilarityRecompute";
    public const string SnapshotRecomputeSubscriptionId = "BridalGlow_SnapshotRecompute";
}
