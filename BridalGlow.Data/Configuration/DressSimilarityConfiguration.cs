using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class DressSimilarityConfiguration : IEntityTypeConfiguration<DressSimilarity>
{
    public void Configure(EntityTypeBuilder<DressSimilarity> builder)
    {
        builder.ToTable("DressSimilarities");
        builder.HasKey(s => s.Id);

        builder.Property(s => s.Score).HasPrecision(8, 6);
        builder.Property(s => s.ModelVersion).HasMaxLength(50).IsRequired();

        builder.HasIndex(s => new { s.DressId, s.SimilarDressId, s.ModelVersion }).IsUnique();

        builder.HasOne(s => s.Dress)
            .WithMany(d => d.SimilarDresses)
            .HasForeignKey(s => s.DressId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(s => s.SimilarDress)
            .WithMany(d => d.SimilarToDresses)
            .HasForeignKey(s => s.SimilarDressId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
