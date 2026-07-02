using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class RentalReservationStatusHistoryConfiguration : IEntityTypeConfiguration<RentalReservationStatusHistory>
{
    public void Configure(EntityTypeBuilder<RentalReservationStatusHistory> builder)
    {
        builder.ToTable("RentalReservationStatusHistories");
        builder.HasKey(h => h.Id);

        builder.Property(h => h.FromStatus).HasConversion<int>();
        builder.Property(h => h.ToStatus).HasConversion<int>();
        builder.Property(h => h.Reason).HasMaxLength(500);

        builder.HasOne(h => h.RentalReservation)
            .WithMany(r => r.StatusHistory)
            .HasForeignKey(h => h.RentalReservationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(h => h.ChangedByUser)
            .WithMany()
            .HasForeignKey(h => h.ChangedByUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
