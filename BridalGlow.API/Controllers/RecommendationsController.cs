using BridalGlow.API.Filters;
using BridalGlow.Model.Constants;
using BridalGlow.Model.Messaging;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Model.Responses;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RecommendationsController : ControllerBase
{
    private readonly IDomainEventPublisher _publisher;
    private readonly IRecommendationQueryService _queryService;

    public RecommendationsController(
        IDomainEventPublisher publisher,
        IRecommendationQueryService queryService)
    {
        _publisher = publisher;
        _queryService = queryService;
    }

    /// <summary>
    /// Returns personalized dress recommendations for the authenticated customer.
    /// Falls back to cold-start recommendations when no snapshot exists.
    /// </summary>
    [HttpGet("for-me")]
    [Authorize(Roles = RoleNames.Customer)]
    public async Task<ActionResult<IReadOnlyList<RecommendationItemResponse>>> GetForMe(
        [FromQuery] int? limit = null)
    {
        var userId = User.GetUserId();
        return Ok(await _queryService.GetForUserAsync(userId, limit));
    }

    /// <summary>
    /// Returns cold-start recommendations for users without personalization history.
    /// </summary>
    [HttpGet("cold-start")]
    [Authorize(Roles = RoleNames.Customer)]
    public async Task<ActionResult<IReadOnlyList<RecommendationItemResponse>>> GetColdStart(
        [FromQuery] int? limit = null)
    {
        return Ok(await _queryService.GetColdStartAsync(limit));
    }

    /// <summary>
    /// Returns recommender pipeline operational status.
    /// </summary>
    [HttpGet("status")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RecommenderStatusResponse>> GetStatus()
    {
        return Ok(await _queryService.GetStatusAsync());
    }

    /// <summary>
    /// Returns top recommended dresses aggregated from the latest snapshot model.
    /// </summary>
    [HttpGet("trends")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<RecommenderTrendsResponse>> GetTrends(
        [FromQuery] int? limit = null)
    {
        return Ok(await _queryService.GetTrendsAsync(limit));
    }

    /// <summary>
    /// Queues an item-item dress similarity recompute job via the outbox → RabbitMQ → worker pipeline.
    /// </summary>
    [HttpPost("recompute-similarity")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    public async Task<IActionResult> RecomputeSimilarity()
    {
        var message = new SimilarityRecomputeRequestedMessage
        {
            RequestedByUserId = User.GetUserId(),
            RequestedAtUtc = DateTime.UtcNow,
            Source = "AdminTrigger"
        };

        await _publisher.EnqueueAsync(message);

        return Accepted(new
        {
            status = "queued",
            eventType = MessagingEventTypes.RecommendationSimilarityRecomputeRequested,
            requestedAtUtc = message.RequestedAtUtc
        });
    }

    /// <summary>
    /// Queues a recommendation snapshot recompute job via the outbox → RabbitMQ → worker pipeline.
    /// </summary>
    [HttpPost("recompute-snapshots")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    public async Task<IActionResult> RecomputeSnapshots()
    {
        var message = new SnapshotRecomputeRequestedMessage
        {
            RequestedByUserId = User.GetUserId(),
            RequestedAtUtc = DateTime.UtcNow,
            Source = "AdminTrigger"
        };

        await _publisher.EnqueueAsync(message);

        return Accepted(new
        {
            status = "queued",
            eventType = MessagingEventTypes.RecommendationSnapshotRecomputeRequested,
            requestedAtUtc = message.RequestedAtUtc
        });
    }
}
