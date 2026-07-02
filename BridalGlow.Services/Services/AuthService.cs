using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Data.Helpers;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace BridalGlow.Services.Services;

public class AuthService : IAuthService
{
    private readonly BridalGlowDbContext _context;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly JwtSettings _jwtSettings;

    public AuthService(
        BridalGlowDbContext context,
        IJwtTokenService jwtTokenService,
        IOptions<JwtSettings> jwtSettings)
    {
        _context = context;
        _jwtTokenService = jwtTokenService;
        _jwtSettings = jwtSettings.Value;
    }

    public async Task<AuthResponse> RegisterAsync(UserRegisterRequest request)
    {
        if (await _context.Users.AnyAsync(u => u.Email == request.Email))
            throw new UserException("User with this email already exists.");

        if (await _context.Users.AnyAsync(u => u.Username == request.Username))
            throw new UserException("User with this username already exists.");

        var salt = PasswordGenerator.GenerateSalt();
        var user = new User
        {
            FirstName = request.FirstName,
            LastName = request.LastName,
            Email = request.Email,
            Username = request.Username,
            Phone = request.Phone,
            DateOfBirth = request.DateOfBirth,
            PasswordSalt = salt,
            PasswordHash = PasswordGenerator.GenerateHash(request.Password, salt),
            Role = UserRole.Customer,
            IsActive = true,
            CreatedAtUtc = DateTime.UtcNow
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return await CreateAuthResponseAsync(user, null, null);
    }

    public async Task<AuthResponse?> LoginAsync(UserLoginRequest request, string? ipAddress, string? deviceInfo)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Username == request.Username);
        if (user == null || !user.IsActive)
            return null;

        if (!PasswordGenerator.VerifyPassword(request.Password, user.PasswordHash, user.PasswordSalt))
            return null;

        user.LastLoginAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return await CreateAuthResponseAsync(user, ipAddress, deviceInfo);
    }

    public async Task<AuthResponse?> RefreshTokenAsync(string refreshToken, string? ipAddress, string? deviceInfo)
    {
        var storedToken = await _context.RefreshTokens
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.Token == refreshToken);

        if (storedToken == null || storedToken.RevokedAtUtc != null || storedToken.ExpiresAtUtc <= DateTime.UtcNow)
            return null;

        if (!storedToken.User.IsActive)
            return null;

        storedToken.RevokedAtUtc = DateTime.UtcNow;
        return await CreateAuthResponseAsync(storedToken.User, ipAddress, deviceInfo, storedToken.Token);
    }

    public async Task LogoutAsync(int userId, string refreshToken)
    {
        var token = await _context.RefreshTokens
            .FirstOrDefaultAsync(t => t.UserId == userId && t.Token == refreshToken && t.RevokedAtUtc == null);

        if (token != null)
        {
            token.RevokedAtUtc = DateTime.UtcNow;
            token.UpdatedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }
    }

    public async Task RevokeRefreshTokenAsync(int userId, string refreshToken)
    {
        await LogoutAsync(userId, refreshToken);
    }

    private async Task<AuthResponse> CreateAuthResponseAsync(
        User user,
        string? ipAddress,
        string? deviceInfo,
        string? replacedToken = null)
    {
        var accessToken = _jwtTokenService.GenerateAccessToken(user);
        var refreshTokenValue = _jwtTokenService.GenerateRefreshToken();
        var refreshExpires = DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenDays);

        var refreshToken = new RefreshToken
        {
            UserId = user.Id,
            Token = refreshTokenValue,
            ExpiresAtUtc = refreshExpires,
            ReplacedByToken = replacedToken,
            IpAddress = ipAddress,
            DeviceInfo = deviceInfo,
            CreatedAtUtc = DateTime.UtcNow
        };

        _context.RefreshTokens.Add(refreshToken);
        await _context.SaveChangesAsync();

        return new AuthResponse
        {
            User = MapToResponse(user),
            AccessToken = accessToken,
            RefreshToken = refreshTokenValue,
            AccessTokenExpiresAtUtc = DateTime.UtcNow.AddMinutes(_jwtSettings.AccessTokenMinutes),
            RefreshTokenExpiresAtUtc = refreshExpires
        };
    }

    private static UserResponse MapToResponse(User user) => new()
    {
        Id = user.Id,
        FirstName = user.FirstName,
        LastName = user.LastName,
        Email = user.Email,
        Username = user.Username,
        Phone = user.Phone,
        DateOfBirth = user.DateOfBirth,
        Role = user.Role,
        RoleName = user.Role.ToString(),
        IsActive = user.IsActive,
        CreatedAtUtc = user.CreatedAtUtc,
        LastLoginAtUtc = user.LastLoginAtUtc
    };
}
