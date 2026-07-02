using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class UserDressInteractionConfiguration : IEntityTypeConfiguration<UserDressInteraction>
{
    public void Configure(EntityTypeBuilder<UserDressInteraction> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("UserDressInteractions");

        builder.Property(i => i.InteractionType).HasConversion<int>();
        builder.Property(i => i.Source).HasConversion<int>();
        builder.Property(i => i.Weight).HasPrecision(8, 4);
        builder.Property(i => i.SessionId).HasMaxLength(100);
        builder.Property(i => i.MetadataJson).HasColumnType("jsonb");

        builder.HasIndex(i => new { i.UserId, i.DressId, i.InteractionType, i.OccurredAtUtc });

        builder.HasOne(i => i.User)
            .WithMany(u => u.DressInteractions)
            .HasForeignKey(i => i.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(i => i.Dress)
            .WithMany(d => d.Interactions)
            .HasForeignKey(i => i.DressId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
