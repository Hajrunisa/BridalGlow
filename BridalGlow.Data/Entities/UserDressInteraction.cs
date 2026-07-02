using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class UserDressInteraction : AuditableEntity
{
    public int UserId { get; set; }
    public int DressId { get; set; }
    public InteractionType InteractionType { get; set; }
    public decimal Weight { get; set; } = 1m;
    public DateTime OccurredAtUtc { get; set; }
    public string? SessionId { get; set; }
    public InteractionSource Source { get; set; }
    public string? MetadataJson { get; set; }

    public User User { get; set; } = null!;
    public Dress Dress { get; set; } = null!;
}
