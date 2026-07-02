using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class OutboxMessageConfiguration : IEntityTypeConfiguration<OutboxMessage>
{
    public void Configure(EntityTypeBuilder<OutboxMessage> builder)
    {
        builder.ToTable("OutboxMessages");

        builder.Property(o => o.EventType).HasMaxLength(200).IsRequired();
        builder.Property(o => o.PayloadJson).HasColumnType("jsonb").IsRequired();
        builder.Property(o => o.Status).HasConversion<int>();
        builder.Property(o => o.Error).HasMaxLength(2000);

        builder.HasIndex(o => new { o.Status, o.CreatedAtUtc });
    }
}
