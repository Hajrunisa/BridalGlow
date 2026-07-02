using Microsoft.Extensions.Configuration;

namespace BridalGlow.Data.Extensions;

public static class ConnectionStringResolver
{
    public static string Resolve(IConfiguration? configuration = null)
    {
        var connectionString = BuildFromEnvironment();

        if (string.IsNullOrWhiteSpace(connectionString) && configuration != null)
            connectionString = configuration.GetConnectionString("DefaultConnection");

        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException(
                "Database connection not configured. Set DB_* environment variables or ConnectionStrings:DefaultConnection.");

        return connectionString;
    }

    public static string? BuildFromEnvironment()
    {
        var mode = Environment.GetEnvironmentVariable("DB_MODE")?.Trim().ToLowerInvariant();
        string? host, port, name, user, password;

        if (mode == "supabase")
        {
            host = Environment.GetEnvironmentVariable("DB_SUPABASE_HOST");
            port = Environment.GetEnvironmentVariable("DB_SUPABASE_PORT");
            name = Environment.GetEnvironmentVariable("DB_SUPABASE_NAME");
            user = Environment.GetEnvironmentVariable("DB_SUPABASE_USER");
            password = Environment.GetEnvironmentVariable("DB_SUPABASE_PASSWORD");
        }
        else
        {
            host = Environment.GetEnvironmentVariable("DB_HOST");
            port = Environment.GetEnvironmentVariable("DB_PORT");
            name = Environment.GetEnvironmentVariable("DB_NAME");
            user = Environment.GetEnvironmentVariable("DB_USER");
            password = Environment.GetEnvironmentVariable("DB_PASSWORD");
        }

        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(user))
            return null;

        return $"Host={host};Port={port ?? "5432"};Database={name};Username={user};Password={password ?? string.Empty}";
    }
}
