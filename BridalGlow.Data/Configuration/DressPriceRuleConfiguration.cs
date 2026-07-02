using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class DressPriceRuleConfiguration : IEntityTypeConfiguration<DressPriceRule>
{
    public void Configure(EntityTypeBuilder<DressPriceRule> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("DressPriceRules");

        builder.Property(r => r.RuleType).HasConversion<int>();
        builder.Property(r => r.Amount).HasPrecision(18, 2);
        builder.Property(r => r.Percent).HasPrecision(5, 2);

        builder.HasOne(r => r.Dress)
            .WithMany(d => d.PriceRules)
            .HasForeignKey(r => r.DressId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
