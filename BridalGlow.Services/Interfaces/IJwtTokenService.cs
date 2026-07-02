using System.Security.Claims;
using BridalGlow.Data.Entities;

namespace BridalGlow.Services.Interfaces;

public interface IJwtTokenService
{
    string GenerateAccessToken(User user);
    string GenerateRefreshToken();
    ClaimsPrincipal? GetPrincipalFromExpiredToken(string token);
}
