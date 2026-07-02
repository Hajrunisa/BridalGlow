using BridalGlow.API.Filters;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Register([FromBody] UserRegisterRequest request)
    {
        var result = await _authService.RegisterAsync(request);
        return Ok(result);
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Login([FromBody] UserLoginRequest request)
    {
        var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
        var device = Request.Headers.UserAgent.ToString();
        var result = await _authService.LoginAsync(request, ip, device);
        if (result == null)
            return Unauthorized();
        return Ok(result);
    }

    [HttpPost("refresh")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Refresh([FromBody] RefreshTokenRequest request)
    {
        var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
        var device = Request.Headers.UserAgent.ToString();
        var result = await _authService.RefreshTokenAsync(request.RefreshToken, ip, device);
        if (result == null)
            return Unauthorized();
        return Ok(result);
    }

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout([FromBody] RefreshTokenRequest request)
    {
        var userId = User.GetUserId();
        await _authService.LogoutAsync(userId, request.RefreshToken);
        return NoContent();
    }

    [HttpPost("revoke")]
    [Authorize]
    public async Task<IActionResult> Revoke([FromBody] RefreshTokenRequest request)
    {
        var userId = User.GetUserId();
        await _authService.RevokeRefreshTokenAsync(userId, request.RefreshToken);
        return NoContent();
    }
}
