using System.Text.Json;
using EasyNetQ;
using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Services.Interfaces;
using BridalGlow.Services.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BridalGlow.Services.Services;

public class OutboxRelayService : IOutboxRelayService
{
    private const int MaxBatchSize = 50;
    private const int MaxRetryCount = 5;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly BridalGlowDbContext _context;
    private readonly IBus _bus;
    private readonly ILogger<OutboxRelayService> _logger;

    public OutboxRelayService(
        BridalGlowDbContext context,
        IBus bus,
        ILogger<OutboxRelayService> logger)
    {
        _context = context;
        _bus = bus;
        _logger = logger;
    }

    public async Task<int> PublishPendingMessagesAsync(CancellationToken cancellationToken = default)
    {
        var pending = await _context.OutboxMessages
            .Where(o => o.Status == OutboxMessageStatus.Pending)
            .OrderBy(o => o.Id)
            .Take(MaxBatchSize)
            .ToListAsync(cancellationToken);

        if (pending.Count == 0)
            return 0;

        var publishedCount = 0;

        foreach (var outboxMessage in pending)
        {
            try
            {
                await PublishOutboxMessageAsync(outboxMessage, cancellationToken);

                outboxMessage.Status = OutboxMessageStatus.Published;
                outboxMessage.PublishedAtUtc = DateTime.UtcNow;
                outboxMessage.Error = null;
                publishedCount++;
            }
            catch (Exception ex)
            {
                outboxMessage.RetryCount++;
                outboxMessage.Error = ex.Message;

                if (outboxMessage.RetryCount >= MaxRetryCount)
                {
                    outboxMessage.Status = OutboxMessageStatus.Failed;
                    _logger.LogError(
                        ex,
                        "Outbox message {OutboxMessageId} ({EventType}) failed permanently after {RetryCount} attempts.",
                        outboxMessage.Id,
                        outboxMessage.EventType,
                        outboxMessage.RetryCount);
                }
                else
                {
                    _logger.LogWarning(
                        ex,
                        "Outbox message {OutboxMessageId} ({EventType}) publish failed (attempt {RetryCount}).",
                        outboxMessage.Id,
                        outboxMessage.EventType,
                        outboxMessage.RetryCount);
                }
            }
        }

        await _context.SaveChangesAsync(cancellationToken);
        return publishedCount;
    }

    private async Task PublishOutboxMessageAsync(OutboxMessage outboxMessage, CancellationToken cancellationToken)
    {
        var clrType = MessagingEventTypeResolver.ResolveClrType(outboxMessage.EventType);
        var message = System.Text.Json.JsonSerializer.Deserialize(outboxMessage.PayloadJson, clrType, JsonOptions);

        if (message == null)
            throw new InvalidOperationException(
                $"Failed to deserialize outbox payload for event type '{outboxMessage.EventType}'.");

        // JsonSerializer.Deserialize(..., Type) returns object, so a direct PublishAsync call
        // would publish as System.Object and miss typed EasyNetQ subscribers.
        switch (message)
        {
            case NotificationRequestedMessage notificationRequested:
                await _bus.PubSub.PublishAsync(notificationRequested, cancellationToken);
                break;
            case InfrastructurePingMessage infrastructurePing:
                await _bus.PubSub.PublishAsync(infrastructurePing, cancellationToken);
                break;
            case SimilarityRecomputeRequestedMessage similarityRecompute:
                await _bus.PubSub.PublishAsync(similarityRecompute, cancellationToken);
                break;
            case SnapshotRecomputeRequestedMessage snapshotRecompute:
                await _bus.PubSub.PublishAsync(snapshotRecompute, cancellationToken);
                break;
            default:
                throw new InvalidOperationException(
                    $"Outbox message type '{message.GetType().Name}' is not supported for RabbitMQ publish.");
        }

        _logger.LogInformation(
            "Published outbox message {OutboxMessageId} ({EventType}) to RabbitMQ.",
            outboxMessage.Id,
            outboxMessage.EventType);
    }
}
