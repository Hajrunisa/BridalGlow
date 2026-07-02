using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class DressImageConfiguration : IEntityTypeConfiguration<DressImage>
{
    public void Configure(EntityTypeBuilder<DressImage> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("DressImages");

        builder.Property(i => i.Url).HasMaxLength(1000).IsRequired();
        builder.Property(i => i.StorageKey).HasMaxLength(500).IsRequired();
        builder.Property(i => i.AltText).HasMaxLength(200);
        builder.Property(i => i.MimeType).HasMaxLength(100);

        builder.HasOne(i => i.Dress)
            .WithMany(d => d.Images)
            .HasForeignKey(i => i.DressId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
