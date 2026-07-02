using BridalGlow.Data.Extensions;
using System.Text;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using BridalGlow.Services.Services;
using Mapster;
using MapsterMapper;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

namespace BridalGlow.Services.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddBridalGlowServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddBridalGlowData(configuration);

        services.AddBridalGlowMessaging(configuration);
        services.AddBridalGlowRecommender(configuration);

        var jwtSettings = new JwtSettings
        {
            SecretKey = JwtSecretResolver.ResolveSecretKey(configuration),
            Issuer = JwtSecretResolver.ResolveIssuer(configuration),
            Audience = JwtSecretResolver.ResolveAudience(configuration),
            AccessTokenMinutes = configuration.GetValue("Jwt:AccessTokenMinutes", 60),
            RefreshTokenDays = configuration.GetValue("Jwt:RefreshTokenDays", 7)
        };

        services.Configure<JwtSettings>(opts =>
        {
            opts.SecretKey = jwtSettings.SecretKey;
            opts.Issuer = jwtSettings.Issuer;
            opts.Audience = jwtSettings.Audience;
            opts.AccessTokenMinutes = jwtSettings.AccessTokenMinutes;
            opts.RefreshTokenDays = jwtSettings.RefreshTokenDays;
        });

        var signingKey = new SymmetricSecurityKey(
            System.Text.Encoding.UTF8.GetBytes(jwtSettings.SecretKey));
        services.AddSingleton(signingKey);

        services.AddMapster();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IUserService, UserService>();
        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<IDressCategoryService, DressCategoryService>();
        services.AddScoped<IDressTagService, DressTagService>();
        services.AddScoped<IDressService, DressService>();
        services.AddScoped<IDressImageService, DressImageService>();
        services.AddScoped<IDressAvailabilitySlotService, DressAvailabilitySlotService>();
        services.AddScoped<IDressPriceRuleService, DressPriceRuleService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<ITryOnReservationService, TryOnReservationService>();
        services.AddScoped<IRentalReservationService, RentalReservationService>();
        services.AddScoped<IPaymentService, PaymentService>();
        services.AddScoped<IFinancialLedgerService, FinancialLedgerService>();
        services.AddScoped<IRefundService, RefundService>();
        services.AddScoped<IStripeWebhookService, StripeWebhookService>();
        services.AddScoped<IReviewService, ReviewService>();
        services.AddScoped<IUserDressInteractionService, UserDressInteractionService>();
        services.AddScoped<IRecommendationQueryService, RecommendationQueryService>();
        services.AddScoped<IMaintenanceRecordService, MaintenanceRecordService>();
        services.AddScoped<IReportingAggregationService, ReportingAggregationService>();
        services.AddScoped<IPdfReportService, PdfReportService>();

        return services;
    }
}
