namespace BridalGlow.Data.Entities;

public class RefreshToken : AuditableEntity
{
    public int UserId { get; set; }
    public string Token { get; set; } = string.Empty;
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime? RevokedAtUtc { get; set; }
    public string? ReplacedByToken { get; set; }
    public string? DeviceInfo { get; set; }
    public string? IpAddress { get; set; }

    public User User { get; set; } = null!;
}
