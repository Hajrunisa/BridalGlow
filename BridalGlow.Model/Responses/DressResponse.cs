using System;
using System.Collections.Generic;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class DressResponse
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Brand { get; set; }
    public string Color { get; set; } = string.Empty;
    public string? Material { get; set; }
    public string? Silhouette { get; set; }
    public string? Neckline { get; set; }
    public string? SleeveType { get; set; }
    public string? TrainLength { get; set; }
    public string SizeLabel { get; set; } = string.Empty;
    public decimal? BustCm { get; set; }
    public decimal? WaistCm { get; set; }
    public decimal? HipCm { get; set; }
    public decimal? LengthCm { get; set; }
    public DressCondition Condition { get; set; }
    public decimal? AcquisitionCost { get; set; }
    public decimal? ReplacementValue { get; set; }
    public decimal BaseRentalPrice { get; set; }
    public decimal? TryOnPrice { get; set; }
    public decimal? DepositAmount { get; set; }
    public DressStatus Status { get; set; }
    public bool IsFeatured { get; set; }
    public decimal AverageRating { get; set; }
    public int RatingCount { get; set; }
    public int PrimaryCategoryId { get; set; }
    public string PrimaryCategoryName { get; set; } = string.Empty;
    public List<DressTagResponse> Tags { get; set; } = new();
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}
