using System;

namespace BridalGlow.Model.Messaging.Messages;

/// <summary>
/// Triggers per-user recommendation snapshot recompute in the worker.
/// </summary>
public class SnapshotRecomputeRequestedMessage
{
    public int? RequestedByUserId { get; set; }

    public DateTime RequestedAtUtc { get; set; }

    public string Source { get; set; } = string.Empty;
}
