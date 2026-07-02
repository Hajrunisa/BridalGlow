using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class PaymentConfiguration : IEntityTypeConfiguration<Payment>
{
    public void Configure(EntityTypeBuilder<Payment> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("Payments");

        builder.Property(p => p.PaymentType).HasConversion<int>();
        builder.Property(p => p.Status).HasConversion<int>();
        builder.Property(p => p.Provider).HasConversion<int>();
        builder.Property(p => p.ProviderPaymentIntentId).HasMaxLength(200);
        builder.Property(p => p.ProviderChargeId).HasMaxLength(200);
        builder.Property(p => p.Amount).HasPrecision(18, 2);
        builder.Property(p => p.CapturedAmount).HasPrecision(18, 2);
        builder.Property(p => p.Currency).HasMaxLength(3).IsRequired();
        builder.Property(p => p.FailedReason).HasMaxLength(500);
        builder.Property(p => p.MetadataJson).HasColumnType("jsonb");

        builder.HasIndex(p => p.ProviderPaymentIntentId).IsUnique();

        builder.HasOne(p => p.RentalReservation)
            .WithMany(r => r.Payments)
            .HasForeignKey(p => p.RentalReservationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(p => p.TryOnReservation)
            .WithMany(r => r.Payments)
            .HasForeignKey(p => p.TryOnReservationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(p => p.Customer)
            .WithMany(u => u.Payments)
            .HasForeignKey(p => p.CustomerUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.ToTable(t => t.HasCheckConstraint(
            "CK_Payments_ReservationTarget",
            "(\"RentalReservationId\" IS NOT NULL AND \"TryOnReservationId\" IS NULL) OR (\"RentalReservationId\" IS NULL AND \"TryOnReservationId\" IS NOT NULL)"));
    }
}
