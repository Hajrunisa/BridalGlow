using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ConfigureAuditableEntity();
        builder.ToTable("RefreshTokens");

        builder.Property(r => r.Token).HasMaxLength(512).IsRequired();
        builder.Property(r => r.ReplacedByToken).HasMaxLength(512);
        builder.Property(r => r.DeviceInfo).HasMaxLength(256);
        builder.Property(r => r.IpAddress).HasMaxLength(64);

        builder.HasIndex(r => r.Token).IsUnique();

        builder.HasOne(r => r.User)
            .WithMany(u => u.RefreshTokens)
            .HasForeignKey(r => r.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
