using BridalGlow.Model.Enums;

namespace BridalGlow.Model.SearchObjects;

public class DressSearchObject : BaseSearchObject
{
    public string? Name { get; set; }
    public string? Code { get; set; }
    public int? CategoryId { get; set; }
    public int? TagId { get; set; }
    public DressStatus? Status { get; set; }
    public DressCondition? Condition { get; set; }
    public string? SizeLabel { get; set; }
    public decimal? MinPrice { get; set; }
    public decimal? MaxPrice { get; set; }
    public bool? IsFeatured { get; set; }
    public decimal? MinRating { get; set; }
    public bool IncludeDeleted { get; set; }

    /// <summary>
    /// Polja sortiranja: Name, Price, Rating, CreatedAt
    /// </summary>
    public string? SortBy { get; set; }

    public bool Descending { get; set; }
}
