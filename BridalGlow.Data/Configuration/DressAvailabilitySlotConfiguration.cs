using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class DressAvailabilitySlotConfiguration : IEntityTypeConfiguration<DressAvailabilitySlot>
{
    public void Configure(EntityTypeBuilder<DressAvailabilitySlot> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("DressAvailabilitySlots");

        builder.Property(s => s.SlotType).HasConversion<int>();
        builder.Property(s => s.SourceReservationType).HasConversion<int>();
        builder.Property(s => s.Reason).HasMaxLength(500);

        builder.HasOne(s => s.Dress)
            .WithMany(d => d.AvailabilitySlots)
            .HasForeignKey(s => s.DressId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
