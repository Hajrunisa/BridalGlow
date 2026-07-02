using System;
using System.Collections.Generic;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class DressListItemResponse
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public string SizeLabel { get; set; } = string.Empty;
    public decimal BaseRentalPrice { get; set; }
    public decimal? TryOnPrice { get; set; }
    public DressStatus Status { get; set; }
    public DressCondition Condition { get; set; }
    public bool IsFeatured { get; set; }
    public decimal AverageRating { get; set; }
    public int RatingCount { get; set; }
    public int PrimaryCategoryId { get; set; }
    public string PrimaryCategoryName { get; set; } = string.Empty;
    public List<string> TagNames { get; set; } = new();
    public DateTime CreatedAtUtc { get; set; }
    public string? PrimaryImageUrl { get; set; }
}
