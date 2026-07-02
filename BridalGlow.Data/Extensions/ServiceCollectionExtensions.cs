using BridalGlow.Data.Database;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BridalGlow.Data.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddBridalGlowData(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = ConnectionStringResolver.Resolve(configuration);

        services.AddDbContext<BridalGlowDbContext>(options =>
        {
            options.UseNpgsql(connectionString);
        });

        return services;
    }
}
