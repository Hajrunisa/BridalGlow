using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class RentalReservationConfiguration : IEntityTypeConfiguration<RentalReservation>
{
    public void Configure(EntityTypeBuilder<RentalReservation> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("RentalReservations");

        builder.Property(r => r.ReservationNumber).HasMaxLength(50).IsRequired();
        builder.Property(r => r.Status).HasConversion<int>();
        builder.Property(r => r.BaseAmount).HasPrecision(18, 2);
        builder.Property(r => r.DiscountAmount).HasPrecision(18, 2);
        builder.Property(r => r.DepositAmount).HasPrecision(18, 2);
        builder.Property(r => r.LateFeeAmount).HasPrecision(18, 2);
        builder.Property(r => r.DamageFeeAmount).HasPrecision(18, 2);
        builder.Property(r => r.TotalAmount).HasPrecision(18, 2);
        builder.Property(r => r.Currency).HasMaxLength(3).IsRequired();
        builder.Property(r => r.Notes).HasMaxLength(1000);
        builder.Property(r => r.CancellationReason).HasMaxLength(500);

        builder.HasIndex(r => r.ReservationNumber).IsUnique();

        builder.HasOne(r => r.Dress)
            .WithMany(d => d.RentalReservations)
            .HasForeignKey(r => r.DressId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.Customer)
            .WithMany(u => u.RentalReservations)
            .HasForeignKey(r => r.CustomerUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
