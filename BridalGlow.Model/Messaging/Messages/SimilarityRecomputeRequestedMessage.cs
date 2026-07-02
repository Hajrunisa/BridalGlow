using System;

namespace BridalGlow.Model.Messaging.Messages;

/// <summary>
/// Triggers item-item dress similarity recompute in the worker.
/// </summary>
public class SimilarityRecomputeRequestedMessage
{
    public int? RequestedByUserId { get; set; }

    public DateTime RequestedAtUtc { get; set; }

    public string Source { get; set; } = string.Empty;
}
