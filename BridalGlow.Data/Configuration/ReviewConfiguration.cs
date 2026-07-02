using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class ReviewConfiguration : IEntityTypeConfiguration<Review>
{
    public void Configure(EntityTypeBuilder<Review> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("Reviews");

        builder.Property(r => r.Rating).IsRequired();
        builder.Property(r => r.Title).HasMaxLength(200);
        builder.Property(r => r.Comment).HasMaxLength(2000);
        builder.Property(r => r.Status).HasConversion<int>();
        builder.Property(r => r.ModerationNote).HasMaxLength(500);
        builder.Property(r => r.StaffReply).HasMaxLength(1000);

        builder.HasIndex(r => new { r.CustomerUserId, r.RentalReservationId }).IsUnique();

        builder.HasOne(r => r.Dress)
            .WithMany(d => d.Reviews)
            .HasForeignKey(r => r.DressId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.Customer)
            .WithMany(u => u.Reviews)
            .HasForeignKey(r => r.CustomerUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.RentalReservation)
            .WithMany(res => res.Reviews)
            .HasForeignKey(r => r.RentalReservationId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
