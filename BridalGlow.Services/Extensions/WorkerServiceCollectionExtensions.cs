using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using BridalGlow.Services.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BridalGlow.Services.Extensions;

public static class WorkerServiceCollectionExtensions
{
    public static IServiceCollection AddBridalGlowWorkerServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddBridalGlowRecommender(configuration);

        services.AddScoped<IDressSimilarityComputationService, DressSimilarityComputationService>();
        services.AddScoped<IRecommendationSnapshotService, RecommendationSnapshotService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<INotificationDeliveryService, NotificationDeliveryService>();
        services.AddScoped<INotificationRealtimeDispatcher, RabbitMqNotificationRealtimeDispatcher>();

        var smtpSettings = SmtpSettingsResolver.Resolve(configuration);
        if (smtpSettings.IsConfigured)
        {
            services.AddSingleton(smtpSettings);
            services.AddScoped<IEmailSenderService, SmtpEmailSenderService>();
        }

        return services;
    }
}
