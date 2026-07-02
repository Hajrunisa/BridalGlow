using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("Notifications");

        builder.Property(n => n.Type).HasConversion<int>();
        builder.Property(n => n.Channel).HasConversion<int>();
        builder.Property(n => n.Status).HasConversion<int>();
        builder.Property(n => n.Title).HasMaxLength(200).IsRequired();
        builder.Property(n => n.Body).HasMaxLength(2000).IsRequired();
        builder.Property(n => n.PayloadJson).HasColumnType("jsonb");
        builder.Property(n => n.RelatedEntityType).HasMaxLength(100);

        builder.HasIndex(n => new { n.UserId, n.Status, n.CreatedAtUtc });

        builder.HasOne(n => n.User)
            .WithMany(u => u.Notifications)
            .HasForeignKey(n => n.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
