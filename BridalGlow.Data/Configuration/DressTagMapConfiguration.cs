using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class DressTagMapConfiguration : IEntityTypeConfiguration<DressTagMap>
{
    public void Configure(EntityTypeBuilder<DressTagMap> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("DressTagMaps");

        builder.HasIndex(m => new { m.DressId, m.DressTagId }).IsUnique();

        builder.HasOne(m => m.Dress)
            .WithMany(d => d.TagMaps)
            .HasForeignKey(m => m.DressId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(m => m.DressTag)
            .WithMany(t => t.DressTagMaps)
            .HasForeignKey(m => m.DressTagId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
