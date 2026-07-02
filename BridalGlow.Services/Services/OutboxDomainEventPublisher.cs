using System.Text.Json;
using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model.Enums;
using BridalGlow.Services.Interfaces;
using BridalGlow.Services.Messaging;

namespace BridalGlow.Services.Services;

public class OutboxDomainEventPublisher : IDomainEventPublisher
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly BridalGlowDbContext _context;

    public OutboxDomainEventPublisher(BridalGlowDbContext context)
    {
        _context = context;
    }

    public void Stage<TMessage>(TMessage message)
    {
        var eventType = MessagingEventTypeResolver.Resolve<TMessage>();
        var payloadJson = JsonSerializer.Serialize(message, JsonOptions);

        _context.OutboxMessages.Add(new OutboxMessage
        {
            EventType = eventType,
            PayloadJson = payloadJson,
            Status = OutboxMessageStatus.Pending,
            CreatedAtUtc = DateTime.UtcNow,
            RetryCount = 0
        });
    }

    public async Task EnqueueAsync<TMessage>(TMessage message, CancellationToken cancellationToken = default)
    {
        Stage(message);
        await _context.SaveChangesAsync(cancellationToken);
    }
}
