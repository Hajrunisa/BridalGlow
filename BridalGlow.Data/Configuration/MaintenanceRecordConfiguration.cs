using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class MaintenanceRecordConfiguration : IEntityTypeConfiguration<MaintenanceRecord>
{
    public void Configure(EntityTypeBuilder<MaintenanceRecord> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("MaintenanceRecords");

        builder.Property(m => m.MaintenanceType).HasConversion<int>();
        builder.Property(m => m.Status).HasConversion<int>();
        builder.Property(m => m.Description).HasMaxLength(1000).IsRequired();
        builder.Property(m => m.CostAmount).HasPrecision(18, 2);
        builder.Property(m => m.VendorName).HasMaxLength(200);
        builder.Property(m => m.InvoiceNumber).HasMaxLength(100);
        builder.Property(m => m.BeforeCondition).HasConversion<int>();
        builder.Property(m => m.AfterCondition).HasConversion<int>();

        builder.HasOne(m => m.Dress)
            .WithMany(d => d.MaintenanceRecords)
            .HasForeignKey(m => m.DressId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(m => m.RecordedByUser)
            .WithMany(u => u.MaintenanceRecords)
            .HasForeignKey(m => m.RecordedByUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
