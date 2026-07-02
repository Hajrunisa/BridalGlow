using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class RefundConfiguration : IEntityTypeConfiguration<Refund>
{
    public void Configure(EntityTypeBuilder<Refund> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("Refunds");

        builder.Property(r => r.Status).HasConversion<int>();
        builder.Property(r => r.ReasonCode).HasConversion<int>();
        builder.Property(r => r.ReasonText).HasMaxLength(500);
        builder.Property(r => r.Amount).HasPrecision(18, 2);
        builder.Property(r => r.Currency).HasMaxLength(3).IsRequired();
        builder.Property(r => r.ProviderRefundId).HasMaxLength(200);
        builder.Property(r => r.FailureReason).HasMaxLength(500);

        builder.HasIndex(r => r.ProviderRefundId).IsUnique();

        builder.HasOne(r => r.Payment)
            .WithMany(p => p.Refunds)
            .HasForeignKey(r => r.PaymentId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.RequestedByUser)
            .WithMany(u => u.RequestedRefunds)
            .HasForeignKey(r => r.RequestedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.ApprovedByUser)
            .WithMany(u => u.ApprovedRefunds)
            .HasForeignKey(r => r.ApprovedByUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
