using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class RecommendationSnapshotConfiguration : IEntityTypeConfiguration<RecommendationSnapshot>
{
    public void Configure(EntityTypeBuilder<RecommendationSnapshot> builder)
    {
        builder.ToTable("RecommendationSnapshots");
        builder.HasKey(s => s.Id);

        builder.Property(s => s.Score).HasPrecision(8, 6);
        builder.Property(s => s.ModelVersion).HasMaxLength(50).IsRequired();

        builder.HasIndex(s => new { s.UserId, s.DressId, s.ModelVersion }).IsUnique();

        builder.HasOne(s => s.User)
            .WithMany(u => u.RecommendationSnapshots)
            .HasForeignKey(s => s.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(s => s.Dress)
            .WithMany(d => d.RecommendationSnapshots)
            .HasForeignKey(s => s.DressId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
