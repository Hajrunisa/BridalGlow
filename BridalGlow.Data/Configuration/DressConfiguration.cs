using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class DressConfiguration : IEntityTypeConfiguration<Dress>
{
    public void Configure(EntityTypeBuilder<Dress> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("Dresses");

        builder.Property(d => d.Code).HasMaxLength(50).IsRequired();
        builder.Property(d => d.Name).HasMaxLength(200).IsRequired();
        builder.Property(d => d.Description).HasMaxLength(2000);
        builder.Property(d => d.Brand).HasMaxLength(100);
        builder.Property(d => d.Color).HasMaxLength(50).IsRequired();
        builder.Property(d => d.Material).HasMaxLength(100);
        builder.Property(d => d.Silhouette).HasMaxLength(100);
        builder.Property(d => d.Neckline).HasMaxLength(100);
        builder.Property(d => d.SleeveType).HasMaxLength(100);
        builder.Property(d => d.TrainLength).HasMaxLength(100);
        builder.Property(d => d.SizeLabel).HasMaxLength(20).IsRequired();

        builder.Property(d => d.BustCm).HasPrecision(8, 2);
        builder.Property(d => d.WaistCm).HasPrecision(8, 2);
        builder.Property(d => d.HipCm).HasPrecision(8, 2);
        builder.Property(d => d.LengthCm).HasPrecision(8, 2);
        builder.Property(d => d.AcquisitionCost).HasPrecision(18, 2);
        builder.Property(d => d.ReplacementValue).HasPrecision(18, 2);
        builder.Property(d => d.BaseRentalPrice).HasPrecision(18, 2);
        builder.Property(d => d.TryOnPrice).HasPrecision(18, 2);
        builder.Property(d => d.DepositAmount).HasPrecision(18, 2);
        builder.Property(d => d.AverageRating).HasPrecision(3, 2);

        builder.Property(d => d.Condition).HasConversion<int>();
        builder.Property(d => d.Status).HasConversion<int>();

        builder.HasIndex(d => d.Code).IsUnique();

        builder.HasOne(d => d.PrimaryCategory)
            .WithMany(c => c.Dresses)
            .HasForeignKey(d => d.PrimaryCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
