using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class OutboxMessage
{
    public int Id { get; set; }
    public string EventType { get; set; } = string.Empty;
    public string PayloadJson { get; set; } = string.Empty;
    public OutboxMessageStatus Status { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? PublishedAtUtc { get; set; }
    public int RetryCount { get; set; }
    public string? Error { get; set; }
}
