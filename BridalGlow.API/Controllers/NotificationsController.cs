using BridalGlow.API.Filters;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _service;

    public NotificationsController(INotificationService service)
    {
        _service = service;
    }

    /// <summary>
    /// Returns the current user's notifications.
    /// Supports filtering by read/unread status and date range.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<PagedResult<NotificationResponse>>> GetMine(
        [FromQuery] NotificationSearchObject? search = null)
    {
        var userId = User.GetUserId();
        return await _service.GetMyNotificationsAsync(userId, search ?? new NotificationSearchObject());
    }

    /// <summary>
    /// Marks a single notification as read.
    /// Only the owner of the notification may mark it.
    /// </summary>
    [HttpPost("{id:int}/read")]
    public async Task<ActionResult<NotificationResponse>> MarkAsRead(int id)
    {
        var userId = User.GetUserId();
        return await _service.MarkAsReadAsync(id, userId);
    }

    /// <summary>
    /// Marks all unread notifications of the current user as read.
    /// </summary>
    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllAsRead()
    {
        var userId = User.GetUserId();
        await _service.MarkAllAsReadAsync(userId);
        return NoContent();
    }
}
