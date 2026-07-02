using BridalGlow.Data.Entities;
using BridalGlow.Data.Seeders;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Data.Database;

public class BridalGlowDbContext : DbContext
{
    public BridalGlowDbContext(DbContextOptions<BridalGlowDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<DressCategory> DressCategories => Set<DressCategory>();
    public DbSet<Dress> Dresses => Set<Dress>();
    public DbSet<DressImage> DressImages => Set<DressImage>();
    public DbSet<DressTag> DressTags => Set<DressTag>();
    public DbSet<DressTagMap> DressTagMaps => Set<DressTagMap>();
    public DbSet<DressPriceRule> DressPriceRules => Set<DressPriceRule>();
    public DbSet<DressAvailabilitySlot> DressAvailabilitySlots => Set<DressAvailabilitySlot>();
    public DbSet<TryOnReservation> TryOnReservations => Set<TryOnReservation>();
    public DbSet<TryOnReservationStatusHistory> TryOnReservationStatusHistories => Set<TryOnReservationStatusHistory>();
    public DbSet<RentalReservation> RentalReservations => Set<RentalReservation>();
    public DbSet<RentalReservationStatusHistory> RentalReservationStatusHistories => Set<RentalReservationStatusHistory>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<ProcessedStripeEvent> ProcessedStripeEvents => Set<ProcessedStripeEvent>();
    public DbSet<Refund> Refunds => Set<Refund>();
    public DbSet<TransactionLedgerEntry> TransactionLedgerEntries => Set<TransactionLedgerEntry>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<MaintenanceRecord> MaintenanceRecords => Set<MaintenanceRecord>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<UserDressInteraction> UserDressInteractions => Set<UserDressInteraction>();
    public DbSet<DressSimilarity> DressSimilarities => Set<DressSimilarity>();
    public DbSet<RecommendationSnapshot> RecommendationSnapshots => Set<RecommendationSnapshot>();
    public DbSet<OutboxMessage> OutboxMessages => Set<OutboxMessage>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(BridalGlowDbContext).Assembly);
        modelBuilder.SeedLookupData();
    }
}
