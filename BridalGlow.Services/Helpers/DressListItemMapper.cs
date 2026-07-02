using BridalGlow.Data.Entities;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Responses;

namespace BridalGlow.Services.Helpers;

public static class DressListItemMapper
{
    public static DressListItemResponse Map(Dress entity) => new()
    {
        Id = entity.Id,
        Code = entity.Code,
        Name = entity.Name,
        Color = entity.Color,
        SizeLabel = entity.SizeLabel,
        BaseRentalPrice = entity.BaseRentalPrice,
        TryOnPrice = entity.TryOnPrice,
        Status = entity.Status,
        Condition = entity.Condition,
        IsFeatured = entity.IsFeatured,
        AverageRating = entity.AverageRating,
        RatingCount = entity.RatingCount,
        PrimaryCategoryId = entity.PrimaryCategoryId,
        PrimaryCategoryName = entity.PrimaryCategory?.Name ?? string.Empty,
        TagNames = entity.TagMaps
            .Where(m => !m.IsDeleted && m.DressTag != null)
            .Select(m => m.DressTag!.Name)
            .ToList(),
        CreatedAtUtc = entity.CreatedAtUtc,
        PrimaryImageUrl = entity.Images.FirstOrDefault(i => !i.IsDeleted)?.Url
    };
}
