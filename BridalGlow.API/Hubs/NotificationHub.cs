using System.Security.Claims;
using BridalGlow.API.Filters;
using BridalGlow.Model.SignalR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace BridalGlow.API.Hubs;

[Authorize]
public class NotificationHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        if (Context.User?.Identity?.IsAuthenticated != true)
        {
            Context.Abort();
            return;
        }

        var userId = Context.User.GetUserId();
        await Groups.AddToGroupAsync(Context.ConnectionId, NotificationHubGroups.User(userId));

        var role = Context.User.FindFirstValue(ClaimTypes.Role);
        if (!string.IsNullOrWhiteSpace(role))
            await Groups.AddToGroupAsync(Context.ConnectionId, NotificationHubGroups.Role(role));

        await base.OnConnectedAsync();
    }
}
