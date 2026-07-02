using BridalGlow.Model.Enums;

namespace BridalGlow.Data.Entities;

public class Dress : AuditableEntity
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Brand { get; set; }
    public string Color { get; set; } = string.Empty;
    public string? Material { get; set; }
    public string? Silhouette { get; set; }
    public string? Neckline { get; set; }
    public string? SleeveType { get; set; }
    public string? TrainLength { get; set; }
    public string SizeLabel { get; set; } = string.Empty;
    public decimal? BustCm { get; set; }
    public decimal? WaistCm { get; set; }
    public decimal? HipCm { get; set; }
    public decimal? LengthCm { get; set; }
    public DressCondition Condition { get; set; }
    public decimal? AcquisitionCost { get; set; }
    public decimal? ReplacementValue { get; set; }
    public decimal BaseRentalPrice { get; set; }
    public decimal? TryOnPrice { get; set; }
    public decimal? DepositAmount { get; set; }
    public DressStatus Status { get; set; }
    public bool IsFeatured { get; set; }
    public decimal AverageRating { get; set; }
    public int RatingCount { get; set; }

    public int PrimaryCategoryId { get; set; }

    public DressCategory PrimaryCategory { get; set; } = null!;
    public ICollection<DressImage> Images { get; set; } = new List<DressImage>();
    public ICollection<DressTagMap> TagMaps { get; set; } = new List<DressTagMap>();
    public ICollection<DressPriceRule> PriceRules { get; set; } = new List<DressPriceRule>();
    public ICollection<DressAvailabilitySlot> AvailabilitySlots { get; set; } = new List<DressAvailabilitySlot>();
    public ICollection<TryOnReservation> TryOnReservations { get; set; } = new List<TryOnReservation>();
    public ICollection<RentalReservation> RentalReservations { get; set; } = new List<RentalReservation>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
    public ICollection<MaintenanceRecord> MaintenanceRecords { get; set; } = new List<MaintenanceRecord>();
    public ICollection<UserDressInteraction> Interactions { get; set; } = new List<UserDressInteraction>();
    public ICollection<DressSimilarity> SimilarDresses { get; set; } = new List<DressSimilarity>();
    public ICollection<DressSimilarity> SimilarToDresses { get; set; } = new List<DressSimilarity>();
    public ICollection<RecommendationSnapshot> RecommendationSnapshots { get; set; } = new List<RecommendationSnapshot>();
}
