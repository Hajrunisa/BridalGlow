using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;

namespace BridalGlow.Services.Interfaces;

public interface IAuthService
{
    Task<AuthResponse> RegisterAsync(UserRegisterRequest request);
    Task<AuthResponse?> LoginAsync(UserLoginRequest request, string? ipAddress, string? deviceInfo);
    Task<AuthResponse?> RefreshTokenAsync(string refreshToken, string? ipAddress, string? deviceInfo);
    Task LogoutAsync(int userId, string refreshToken);
    Task RevokeRefreshTokenAsync(int userId, string refreshToken);
}
