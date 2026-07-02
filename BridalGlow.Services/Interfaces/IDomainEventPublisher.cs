namespace BridalGlow.Services.Interfaces;

/// <summary>
/// Enqueues domain/integration messages into the transactional outbox for reliable publish.
/// </summary>
public interface IDomainEventPublisher
{
    /// <summary>
    /// Stages a message in the outbox without committing. Caller must invoke SaveChanges on the shared DbContext.
    /// </summary>
    void Stage<TMessage>(TMessage message);

    /// <summary>
    /// Stages a message and commits immediately (standalone enqueue).
    /// </summary>
    Task EnqueueAsync<TMessage>(TMessage message, CancellationToken cancellationToken = default);
}
