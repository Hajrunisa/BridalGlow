using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class ProcessedStripeEventConfiguration : IEntityTypeConfiguration<ProcessedStripeEvent>
{
    public void Configure(EntityTypeBuilder<ProcessedStripeEvent> builder)
    {
        builder.ToTable("ProcessedStripeEvents");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.EventId).HasMaxLength(200).IsRequired();
        builder.Property(e => e.EventType).HasMaxLength(200).IsRequired();
        builder.Property(e => e.ProcessedAtUtc).IsRequired();

        builder.HasIndex(e => e.EventId).IsUnique();
    }
}
