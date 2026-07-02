using BridalGlow.API.Extensions;
using BridalGlow.API.Filters;
using BridalGlow.API.Health;
using BridalGlow.Data.Database;
using BridalGlow.Data.Seeders;
using BridalGlow.Services.Extensions;
using DotNetEnv;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi.Models;

AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);

// Resolve uploads root early so it can be used both in DI and in middleware
var uploadsRoot = Environment.GetEnvironmentVariable("UPLOAD_PATH")
    ?? Path.Combine(builder.Environment.ContentRootPath, "uploads");
Directory.CreateDirectory(uploadsRoot);

var seedImagesSource = SeedImageFileInitializer.ResolveSeedImagesSourceDirectory(
    builder.Environment.ContentRootPath);
SeedImageFileInitializer.EnsureSeedImagesCopied(seedImagesSource, uploadsRoot);

var port = Environment.GetEnvironmentVariable("PORT");
if (!string.IsNullOrEmpty(port))
    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

builder.Services.AddScoped<ExceptionFilter>();
builder.Services.AddHttpContextAccessor();

builder.Services.AddBridalGlowServices(builder.Configuration);
builder.Services.AddBridalGlowJwtAuthentication(builder.Configuration);
builder.Services.AddAuthorization();

builder.Services.AddControllers(options =>
{
    options.Filters.AddService<ExceptionFilter>();
})
.AddJsonOptions(options =>
{
    options.JsonSerializerOptions.Converters.Add(new System.Text.Json.Serialization.JsonStringEnumConverter());
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "BridalGlow API",
        Version = "v1",
        Description = "Wedding dresses"
    });

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Enter JWT token"
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());

    options.AddPolicy(BridalGlow.API.Extensions.ServiceCollectionExtensions.SignalRCorsPolicyName, policy =>
        policy.SetIsOriginAllowed(_ => true)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials());
});

builder.Services.AddHealthChecks()
    .AddCheck<BridalGlowHealthCheck>("bridalglow");
builder.Services.AddBridalGlowSignalR();

builder.Services.Configure<HostOptions>(options =>
{
    // A RabbitMQ subscribe retry must not terminate the web host (.NET 6+ default is StopHost).
    options.BackgroundServiceExceptionBehavior = BackgroundServiceExceptionBehavior.Ignore;
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<BridalGlowDbContext>();
    db.Database.Migrate();
    db.SeedBusinessData();
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();

// Serve uploaded dress images from /uploads without requiring authentication
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(uploadsRoot),
    RequestPath = "/uploads"
});

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health");
app.MapBridalGlowSignalR();

app.Run();
