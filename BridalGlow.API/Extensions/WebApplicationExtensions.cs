using BridalGlow.API.Hubs;
using BridalGlow.API.Extensions;
using BridalGlow.Model.SignalR;

namespace BridalGlow.API.Extensions;

public static class WebApplicationExtensions
{
    public static WebApplication MapBridalGlowSignalR(this WebApplication app)
    {
        app.MapHub<NotificationHub>(NotificationHubRoutes.HubPath)
            .RequireCors(ServiceCollectionExtensions.SignalRCorsPolicyName);

        return app;
    }
}
