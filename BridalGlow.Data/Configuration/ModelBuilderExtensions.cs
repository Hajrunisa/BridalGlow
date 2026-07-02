using BridalGlow.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BridalGlow.Data.Configuration;

public static class ModelBuilderExtensions
{
    public static void ConfigureAuditableEntity<TEntity>(this EntityTypeBuilder<TEntity> builder)
        where TEntity : AuditableEntity
    {
        builder.HasKey(e => e.Id);
        builder.Property(e => e.CreatedAtUtc).IsRequired();
        builder.Property(e => e.IsDeleted).HasDefaultValue(false);
    }
}
