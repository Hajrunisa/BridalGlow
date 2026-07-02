using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class DressCategoryConfiguration : IEntityTypeConfiguration<DressCategory>
{
    public void Configure(EntityTypeBuilder<DressCategory> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("DressCategories");

        builder.Property(c => c.Name).HasMaxLength(100).IsRequired();
        builder.Property(c => c.Description).HasMaxLength(500);

        builder.HasIndex(c => c.Name).IsUnique();
    }
}
