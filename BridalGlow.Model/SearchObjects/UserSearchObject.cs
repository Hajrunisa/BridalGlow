using BridalGlow.Model.Enums;

namespace BridalGlow.Model.SearchObjects;

public class UserSearchObject : BaseSearchObject
{
    public string? Username { get; set; }
    public string? Email { get; set; }
    public UserRole? Role { get; set; }
    public bool? IsActive { get; set; }
}
