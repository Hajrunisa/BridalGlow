using BridalGlow.API.Filters;
using BridalGlow.Model.Constants;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

/// <summary>
/// Development-only endpoints for verifying messaging infrastructure (outbox → RabbitMQ → worker).
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = RoleNames.Admin)]
public class MessagingDiagnosticsController : ControllerBase
{
    private readonly IDomainEventPublisher _publisher;
    private readonly IWebHostEnvironment _environment;

    public MessagingDiagnosticsController(
        IDomainEventPublisher publisher,
        IWebHostEnvironment environment)
    {
        _publisher = publisher;
        _environment = environment;
    }

    /// <summary>
    /// Enqueues an infrastructure ping message into the outbox for pipeline verification.
    /// </summary>
    [HttpPost("outbox-ping")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> EnqueueOutboxPing()
    {
        if (!_environment.IsDevelopment())
            return NotFound();

        var message = new InfrastructurePingMessage
        {
            Message = "BridalGlow outbox infrastructure ping",
            SentAtUtc = DateTime.UtcNow,
            Source = "BridalGlow.API"
        };

        await _publisher.EnqueueAsync(message);

        return Ok(new
        {
            status = "queued",
            eventType = message.GetType().Name,
            sentAtUtc = message.SentAtUtc
        });
    }

    /// <summary>
    /// Enqueues a notification request into the outbox for worker delivery pipeline verification.
    /// </summary>
    [HttpPost("outbox-notification")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> EnqueueOutboxNotification()
    {
        if (!_environment.IsDevelopment())
            return NotFound();

        var userId = User.GetUserId();
        var now = DateTime.UtcNow;

        var message = new NotificationRequestedMessage
        {
            UserId = userId,
            Title = "Test notifikacija (Worker pipeline)",
            Body = "Ova notifikacija je kreirana putem outbox → RabbitMQ → worker toka.",
            Type = NotificationType.System,
            Channel = NotificationChannel.InApp,
            RelatedEntityType = "MessagingDiagnostics",
            RelatedEntityId = (int)(now.Ticks % int.MaxValue),
            SendEmail = false
        };

        await _publisher.EnqueueAsync(message);

        return Ok(new
        {
            status = "queued",
            userId,
            type = message.Type.ToString(),
            relatedEntityType = message.RelatedEntityType,
            relatedEntityId = message.RelatedEntityId
        });
    }
}
