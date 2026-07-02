using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class TryOnReservationConfiguration : IEntityTypeConfiguration<TryOnReservation>
{
    public void Configure(EntityTypeBuilder<TryOnReservation> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("TryOnReservations");

        builder.Property(r => r.ReservationNumber).HasMaxLength(50).IsRequired();
        builder.Property(r => r.Status).HasConversion<int>();
        builder.Property(r => r.PriceAmount).HasPrecision(18, 2);
        builder.Property(r => r.DepositAmount).HasPrecision(18, 2);
        builder.Property(r => r.Notes).HasMaxLength(1000);
        builder.Property(r => r.CancellationReason).HasMaxLength(500);

        builder.HasIndex(r => r.ReservationNumber).IsUnique();

        builder.HasOne(r => r.Dress)
            .WithMany(d => d.TryOnReservations)
            .HasForeignKey(r => r.DressId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.Customer)
            .WithMany(u => u.TryOnReservations)
            .HasForeignKey(r => r.CustomerUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
