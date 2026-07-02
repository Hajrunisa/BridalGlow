using BridalGlow.Model.Enums;

namespace BridalGlow.Model.SearchObjects;

public class ReviewSearchObject : BaseSearchObject
{
    public ReviewStatus? Status { get; set; }
    public int? DressId { get; set; }
    public int? CustomerUserId { get; set; }
    public int? MinRating { get; set; }
    public int? MaxRating { get; set; }
}
