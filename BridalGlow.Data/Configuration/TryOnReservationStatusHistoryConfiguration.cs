using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class TryOnReservationStatusHistoryConfiguration : IEntityTypeConfiguration<TryOnReservationStatusHistory>
{
    public void Configure(EntityTypeBuilder<TryOnReservationStatusHistory> builder)
    {
        builder.ToTable("TryOnReservationStatusHistories");
        builder.HasKey(h => h.Id);

        builder.Property(h => h.FromStatus).HasConversion<int>();
        builder.Property(h => h.ToStatus).HasConversion<int>();
        builder.Property(h => h.Reason).HasMaxLength(500);

        builder.HasOne(h => h.TryOnReservation)
            .WithMany(r => r.StatusHistory)
            .HasForeignKey(h => h.TryOnReservationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(h => h.ChangedByUser)
            .WithMany()
            .HasForeignKey(h => h.ChangedByUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
