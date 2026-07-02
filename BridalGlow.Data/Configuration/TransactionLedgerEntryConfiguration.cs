using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class TransactionLedgerEntryConfiguration : IEntityTypeConfiguration<TransactionLedgerEntry>
{
    public void Configure(EntityTypeBuilder<TransactionLedgerEntry> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("TransactionLedgerEntries");

        builder.Property(e => e.EntryType).HasConversion<int>();
        builder.Property(e => e.Direction).HasConversion<int>();
        builder.Property(e => e.Amount).HasPrecision(18, 2);
        builder.Property(e => e.Currency).HasMaxLength(3).IsRequired();
        builder.Property(e => e.Description).HasMaxLength(500).IsRequired();
        builder.Property(e => e.ExternalReference).HasMaxLength(200);

        builder.HasOne(e => e.Payment)
            .WithMany(p => p.LedgerEntries)
            .HasForeignKey(e => e.PaymentId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(e => e.Refund)
            .WithMany(r => r.LedgerEntries)
            .HasForeignKey(e => e.RefundId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(e => e.RentalReservation)
            .WithMany(r => r.LedgerEntries)
            .HasForeignKey(e => e.RentalReservationId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
