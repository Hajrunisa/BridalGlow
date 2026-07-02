using BridalGlow.Data.Extensions;
using BridalGlow.Services.Extensions;
using BridalGlow.Worker.Services;
using DotNetEnv;

var builder = Host.CreateApplicationBuilder(args);

Env.TraversePath().Load();

builder.Services.AddBridalGlowData(builder.Configuration);
builder.Services.AddBridalGlowMessaging(builder.Configuration);
builder.Services.AddBridalGlowWorkerServices(builder.Configuration);

builder.Services.AddHostedService<OutboxRelayHostedService>();
builder.Services.AddHostedService<InfrastructurePingConsumerHostedService>();
builder.Services.AddHostedService<NotificationConsumerHostedService>();
builder.Services.AddHostedService<TryOnReminderHostedService>();
builder.Services.AddHostedService<SimilarityRecomputeConsumerHostedService>();
builder.Services.AddHostedService<DressSimilarityRecomputeHostedService>();
builder.Services.AddHostedService<SnapshotRecomputeConsumerHostedService>();
builder.Services.AddHostedService<RecommendationSnapshotHostedService>();

var host = builder.Build();
await host.RunAsync();
