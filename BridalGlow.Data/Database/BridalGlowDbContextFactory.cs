using BridalGlow.Data.Database;
using BridalGlow.Data.Extensions;
using DotNetEnv;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace BridalGlow.Data.Database;

public class BridalGlowDbContextFactory : IDesignTimeDbContextFactory<BridalGlowDbContext>
{
    public BridalGlowDbContext CreateDbContext(string[] args)
    {
        Env.TraversePath().Load();

        var connectionString = ConnectionStringResolver.BuildFromEnvironment()
            ?? "Host=localhost;Port=5432;Database=200208;Username=postgres;Password=postgres";

        var optionsBuilder = new DbContextOptionsBuilder<BridalGlowDbContext>();
        optionsBuilder.UseNpgsql(connectionString);

        return new BridalGlowDbContext(optionsBuilder.Options);
    }
}
