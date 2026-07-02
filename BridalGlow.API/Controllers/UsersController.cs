using BridalGlow.API.Filters;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;

    public UsersController(IUserService userService)
    {
        _userService = userService;
    }

    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<ActionResult<PagedResult<UserResponse>>> Get([FromQuery] UserSearchObject? search = null)
    {
        return await _userService.GetAsync(search ?? new UserSearchObject());
    }

    [HttpGet("me")]
    public async Task<ActionResult<UserResponse>> GetMyProfile()
    {
        var user = await _userService.GetMyProfileAsync(User.GetUserId());
        if (user == null)
            return NotFound();
        return user;
    }

    [HttpPut("me")]
    public async Task<ActionResult<UserResponse>> UpdateMyProfile([FromBody] UserUpdateProfileRequest request)
    {
        var user = await _userService.UpdateProfileAsync(User.GetUserId(), request);
        if (user == null)
            return NotFound();
        return user;
    }

    [HttpPut("me/password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        await _userService.ChangePasswordAsync(User.GetUserId(), request);
        return NoContent();
    }

    [HttpPut("{id}/activate")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ActivateUser(int id)
    {
        var success = await _userService.ActivateUserAsync(id);
        if (!success)
            return NotFound();
        return NoContent();
    }

    [HttpPut("{id}/deactivate")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeactivateUser(int id)
    {
        var success = await _userService.DeactivateUserAsync(id);
        if (!success)
            return NotFound();
        return NoContent();
    }

    [HttpPut("{id}/promote-to-staff")]
    [Authorize(Roles = "Admin")]
    public async Task<ActionResult<UserResponse>> PromoteToStaff(int id)
    {
        return await _userService.PromoteToSalonStaffAsync(id);
    }
}
