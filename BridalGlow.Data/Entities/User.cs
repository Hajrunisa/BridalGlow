using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class User : AuditableEntity
{
    public string Email { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string PasswordSalt { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public UserRole Role { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? LastLoginAtUtc { get; set; }

    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
    public ICollection<TryOnReservation> TryOnReservations { get; set; } = new List<TryOnReservation>();
    public ICollection<RentalReservation> RentalReservations { get; set; } = new List<RentalReservation>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
    public ICollection<Refund> RequestedRefunds { get; set; } = new List<Refund>();
    public ICollection<Refund> ApprovedRefunds { get; set; } = new List<Refund>();
    public ICollection<MaintenanceRecord> MaintenanceRecords { get; set; } = new List<MaintenanceRecord>();
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
    public ICollection<UserDressInteraction> DressInteractions { get; set; } = new List<UserDressInteraction>();
    public ICollection<RecommendationSnapshot> RecommendationSnapshots { get; set; } = new List<RecommendationSnapshot>();
}
