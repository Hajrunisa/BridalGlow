using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class DressTagConfiguration : IEntityTypeConfiguration<DressTag>
{
    public void Configure(EntityTypeBuilder<DressTag> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("DressTags");

        builder.Property(t => t.Name).HasMaxLength(100).IsRequired();
        builder.HasIndex(t => t.Name).IsUnique();
    }
}
