using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IUserService : IService<UserResponse, UserSearchObject>
{
    Task<UserResponse?> GetMyProfileAsync(int userId);
    Task<UserResponse?> UpdateProfileAsync(int userId, UserUpdateProfileRequest request);
    Task ChangePasswordAsync(int userId, ChangePasswordRequest request);
    Task<bool> ActivateUserAsync(int id);
    Task<bool> DeactivateUserAsync(int id);
    Task<UserResponse> PromoteToSalonStaffAsync(int id);
}
