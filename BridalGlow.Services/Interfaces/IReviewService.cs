using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IReviewService
{
    /// <summary>
    /// Customer creates a review for a completed rental reservation.
    /// </summary>
    Task<ReviewResponse> CreateAsync(int customerId, ReviewCreateRequest request);

    /// <summary>
    /// Customer retrieves their own reviews.
    /// </summary>
    Task<PagedResult<ReviewResponse>> GetMineAsync(int customerId, ReviewSearchObject search);

    /// <summary>
    /// Customer updates their own review (only allowed while status is PendingModeration).
    /// </summary>
    Task<ReviewResponse> UpdateAsync(int id, int customerId, ReviewUpdateRequest request);

    /// <summary>
    /// Public listing of Published reviews for a specific dress.
    /// </summary>
    Task<PagedResult<ReviewResponse>> GetPublishedByDressAsync(int dressId, ReviewSearchObject search);

    /// <summary>
    /// Staff/Admin full listing with all filters.
    /// </summary>
    Task<PagedResult<ReviewResponse>> GetAllAsync(ReviewSearchObject search);

    /// <summary>
    /// Returns a single review by ID. Staff can see any; customers can see only their own.
    /// </summary>
    Task<ReviewResponse?> GetByIdAsync(int id, int? requestingUserId = null, bool isStaff = false);

    // ── Moderation (Staff/Admin) ──────────────────────────────────────────────

    /// <summary>
    /// Publishes a PendingModeration review. Updates Dress rating aggregation and creates ReviewSubmitted interaction.
    /// </summary>
    Task<ReviewResponse> PublishAsync(int id, int staffUserId);

    /// <summary>
    /// Hides a Published review. Updates Dress rating aggregation.
    /// </summary>
    Task<ReviewResponse> HideAsync(int id, int staffUserId);

    /// <summary>
    /// Rejects a PendingModeration review with an optional moderation note.
    /// </summary>
    Task<ReviewResponse> RejectAsync(int id, int staffUserId, ReviewModerationRequest request);

    /// <summary>
    /// Sets or updates the staff reply on a Published review.
    /// </summary>
    Task<ReviewResponse> SetStaffReplyAsync(int id, int staffUserId, ReviewStaffReplyRequest request);
}
