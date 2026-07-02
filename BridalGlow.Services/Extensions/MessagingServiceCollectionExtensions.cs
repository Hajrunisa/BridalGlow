using EasyNetQ;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using BridalGlow.Services.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BridalGlow.Services.Extensions;

public static class MessagingServiceCollectionExtensions
{
    public static IServiceCollection AddBridalGlowMessaging(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var rabbitMqSettings = RabbitMqSettingsResolver.Resolve(configuration);
        services.AddSingleton(rabbitMqSettings);

        services.AddSingleton<IBus>(_ => RabbitHutch.CreateBus(rabbitMqSettings.BuildConnectionString()));

        services.AddScoped<IDomainEventPublisher, OutboxDomainEventPublisher>();
        services.AddScoped<IOutboxRelayService, OutboxRelayService>();
        services.AddScoped<IDomainNotificationPublisher, DomainNotificationPublisher>();

        return services;
    }
}
