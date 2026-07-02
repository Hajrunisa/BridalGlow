using BridalGlow.API.Hubs;
using BridalGlow.API.Services;
using BridalGlow.Model.SignalR;

namespace BridalGlow.API.Extensions;

public static class ServiceCollectionExtensions
{
    public const string SignalRCorsPolicyName = "SignalR";

    public static IServiceCollection AddBridalGlowSignalR(this IServiceCollection services)
    {
        services.AddSignalR();
        services.AddScoped<INotificationSignalRService, NotificationSignalRService>();
        services.AddHostedService<NotificationPushConsumerHostedService>();

        return services;
    }
}
