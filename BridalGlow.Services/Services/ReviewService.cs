using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BridalGlow.Services.Services;

public class ReviewService : IReviewService
{
    private readonly BridalGlowDbContext _context;
    private readonly IDomainNotificationPublisher _domainNotifications;
    private readonly IUserDressInteractionService _interactionService;
    private readonly ILogger<ReviewService> _logger;

    public ReviewService(
        BridalGlowDbContext context,
        IDomainNotificationPublisher domainNotifications,
        IUserDressInteractionService interactionService,
        ILogger<ReviewService> logger)
    {
        _context = context;
        _domainNotifications = domainNotifications;
        _interactionService = interactionService;
        _logger = logger;
    }

    // ── Create ────────────────────────────────────────────────────────────────

    public async Task<ReviewResponse> CreateAsync(int customerId, ReviewCreateRequest request)
    {
        var reservation = await _context.RentalReservations
            .Include(r => r.Dress)
            .FirstOrDefaultAsync(r => r.Id == request.RentalReservationId && !r.IsDeleted);

        if (reservation == null)
            throw new UserException("Rental rezervacija nije pronađena.");

        if (reservation.CustomerUserId != customerId)
            throw new UserException("Nemate dozvolu za recenziju ove rezervacije.");

        if (reservation.Status != RentalReservationStatus.Completed)
            throw new UserException("Recenzija je moguća samo za završene (Completed) rezervacije.");

        var alreadyExists = await _context.Reviews
            .AnyAsync(r => r.CustomerUserId == customerId
                        && r.RentalReservationId == request.RentalReservationId
                        && !r.IsDeleted);

        if (alreadyExists)
            throw new UserException("Već ste ostavili recenziju za ovu rezervaciju.");

        var now = DateTime.UtcNow;

        var review = new Review
        {
            DressId = reservation.DressId,
            CustomerUserId = customerId,
            RentalReservationId = request.RentalReservationId,
            Rating = request.Rating,
            Title = request.Title?.Trim(),
            Comment = request.Comment?.Trim(),
            Status = ReviewStatus.PendingModeration,
            CreatedAtUtc = now,
            IsDeleted = false
        };

        _context.Reviews.Add(review);
        await _context.SaveChangesAsync();

        return await LoadAndMapAsync(review.Id);
    }

    // ── Customer: own reviews ─────────────────────────────────────────────────

    public async Task<PagedResult<ReviewResponse>> GetMineAsync(int customerId, ReviewSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery()
            .Where(r => r.CustomerUserId == customerId);

        query = ApplyFilter(query, search);

        int? totalCount = null;
        if (search.IncludeTotalCount)
            totalCount = await query.CountAsync();

        if (!search.RetrieveAll)
        {
            if (search.Page.HasValue && search.PageSize.HasValue)
                query = query.Skip(search.Page.Value * search.PageSize.Value);
            if (search.PageSize.HasValue)
                query = query.Take(search.PageSize.Value);
        }

        var items = await query.OrderByDescending(r => r.CreatedAtUtc).ToListAsync();
        return new PagedResult<ReviewResponse>
        {
            Items = items.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    // ── Customer: update own review ───────────────────────────────────────────

    public async Task<ReviewResponse> UpdateAsync(int id, int customerId, ReviewUpdateRequest request)
    {
        var review = await _context.Reviews
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (review == null)
            throw new UserException("Recenzija nije pronađena.");

        if (review.CustomerUserId != customerId)
            throw new UserException("Nemate dozvolu za izmjenu ove recenzije.");

        if (review.Status != ReviewStatus.PendingModeration)
            throw new UserException("Recenzija se može mijenjati samo dok je u statusu PendingModeration.");

        if (request.Rating.HasValue)
            review.Rating = request.Rating.Value;

        review.Title = request.Title?.Trim() ?? review.Title;
        review.Comment = request.Comment?.Trim() ?? review.Comment;
        review.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return await LoadAndMapAsync(review.Id);
    }

    // ── Public: published reviews by dress ───────────────────────────────────

    public async Task<PagedResult<ReviewResponse>> GetPublishedByDressAsync(int dressId, ReviewSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery()
            .Where(r => r.DressId == dressId && r.Status == ReviewStatus.Published);

        if (search.MinRating.HasValue)
            query = query.Where(r => r.Rating >= search.MinRating.Value);
        if (search.MaxRating.HasValue)
            query = query.Where(r => r.Rating <= search.MaxRating.Value);

        int? totalCount = null;
        if (search.IncludeTotalCount)
            totalCount = await query.CountAsync();

        if (!search.RetrieveAll)
        {
            if (search.Page.HasValue && search.PageSize.HasValue)
                query = query.Skip(search.Page.Value * search.PageSize.Value);
            if (search.PageSize.HasValue)
                query = query.Take(search.PageSize.Value);
        }

        var items = await query.OrderByDescending(r => r.PublishedAtUtc).ToListAsync();
        return new PagedResult<ReviewResponse>
        {
            Items = items.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    // ── Staff/Admin: full listing ─────────────────────────────────────────────

    public async Task<PagedResult<ReviewResponse>> GetAllAsync(ReviewSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery();
        query = ApplyFilter(query, search);

        int? totalCount = null;
        if (search.IncludeTotalCount)
            totalCount = await query.CountAsync();

        if (!search.RetrieveAll)
        {
            if (search.Page.HasValue && search.PageSize.HasValue)
                query = query.Skip(search.Page.Value * search.PageSize.Value);
            if (search.PageSize.HasValue)
                query = query.Take(search.PageSize.Value);
        }

        var items = await query.OrderByDescending(r => r.CreatedAtUtc).ToListAsync();
        return new PagedResult<ReviewResponse>
        {
            Items = items.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    // ── Get by ID ─────────────────────────────────────────────────────────────

    public async Task<ReviewResponse?> GetByIdAsync(int id, int? requestingUserId = null, bool isStaff = false)
    {
        var review = await BuildBaseQuery()
            .FirstOrDefaultAsync(r => r.Id == id);

        if (review == null)
            return null;

        if (!isStaff && requestingUserId.HasValue && review.CustomerUserId != requestingUserId.Value)
            throw new UserException("Nemate dozvolu za pregled ove recenzije.");

        return MapToResponse(review);
    }

    // ── Moderation (Staff/Admin) ──────────────────────────────────────────────

    public async Task<ReviewResponse> PublishAsync(int id, int staffUserId)
    {
        var review = await GetReviewOrThrowAsync(id);

        if (review.Status != ReviewStatus.PendingModeration)
            throw new UserException($"Samo recenzije sa statusom PendingModeration mogu biti objavljene. Trenutni status: {review.Status}.");

        var now = DateTime.UtcNow;

        review.Status = ReviewStatus.Published;
        review.PublishedAtUtc = now;
        review.UpdatedAtUtc = now;

        await _context.SaveChangesAsync();

        await RecalculateDressRatingAsync(review.DressId);

        try
        {
            await _interactionService.RecordInteractionAsync(
                review.CustomerUserId,
                review.DressId,
                InteractionType.ReviewSubmitted,
                InteractionSource.System,
                metadataJson: UserDressInteractionService.BuildReservationMetadata("reviewId", review.Id));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                ex,
                "Neuspješan zapis ReviewSubmitted interakcije (review {ReviewId}, user {UserId}, dress {DressId}).",
                review.Id,
                review.CustomerUserId,
                review.DressId);
        }

        _domainNotifications.StageCustomerNotification(
            review.CustomerUserId,
            "Vaša recenzija je objavljena",
            "Vaša recenzija je prošla moderaciju i sada je vidljiva svim korisnicima. Hvala što dijelite iskustvo!",
            NotificationType.ReviewModeration,
            relatedEntityType: "Review",
            relatedEntityId: review.Id);

        await _context.SaveChangesAsync();

        return await LoadAndMapAsync(review.Id);
    }

    public async Task<ReviewResponse> HideAsync(int id, int staffUserId)
    {
        var review = await GetReviewOrThrowAsync(id);

        if (review.Status != ReviewStatus.Published)
            throw new UserException($"Samo objavljene (Published) recenzije mogu biti skrivene. Trenutni status: {review.Status}.");

        var now = DateTime.UtcNow;

        review.Status = ReviewStatus.Hidden;
        review.HiddenAtUtc = now;
        review.UpdatedAtUtc = now;

        await _context.SaveChangesAsync();

        await RecalculateDressRatingAsync(review.DressId);

        _domainNotifications.StageCustomerNotification(
            review.CustomerUserId,
            "Vaša recenzija je skrivena",
            "Vaša recenzija je privremeno uklonjena iz javnog prikaza od strane moderatora.",
            NotificationType.ReviewModeration,
            relatedEntityType: "Review",
            relatedEntityId: review.Id);

        await _context.SaveChangesAsync();

        return await LoadAndMapAsync(review.Id);
    }

    public async Task<ReviewResponse> RejectAsync(int id, int staffUserId, ReviewModerationRequest request)
    {
        var review = await GetReviewOrThrowAsync(id);

        if (review.Status != ReviewStatus.PendingModeration)
            throw new UserException($"Samo recenzije sa statusom PendingModeration mogu biti odbijene. Trenutni status: {review.Status}.");

        var now = DateTime.UtcNow;

        review.Status = ReviewStatus.Rejected;
        review.ModerationNote = request.ModerationNote?.Trim();
        review.UpdatedAtUtc = now;

        await _context.SaveChangesAsync();

        await RecalculateDressRatingAsync(review.DressId);

        var notificationBody = string.IsNullOrWhiteSpace(request.ModerationNote)
            ? "Vaša recenzija nije prošla moderaciju."
            : $"Vaša recenzija nije prošla moderaciju. Razlog: {request.ModerationNote.Trim()}";

        _domainNotifications.StageCustomerNotification(
            review.CustomerUserId,
            "Vaša recenzija je odbijena",
            notificationBody,
            NotificationType.ReviewModeration,
            relatedEntityType: "Review",
            relatedEntityId: review.Id);

        await _context.SaveChangesAsync();

        return await LoadAndMapAsync(review.Id);
    }

    public async Task<ReviewResponse> SetStaffReplyAsync(int id, int staffUserId, ReviewStaffReplyRequest request)
    {
        var review = await GetReviewOrThrowAsync(id);

        if (review.Status != ReviewStatus.Published)
            throw new UserException("Odgovor osoblja može se dodati samo na objavljene (Published) recenzije.");

        review.StaffReply = request.StaffReply.Trim();
        review.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return await LoadAndMapAsync(review.Id);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private IQueryable<Review> BuildBaseQuery()
    {
        return _context.Reviews
            .Include(r => r.Dress)
            .Include(r => r.Customer)
            .Where(r => !r.IsDeleted);
    }

    private static IQueryable<Review> ApplyFilter(IQueryable<Review> query, ReviewSearchObject search)
    {
        if (search.Status.HasValue)
            query = query.Where(r => r.Status == search.Status.Value);

        if (search.DressId.HasValue)
            query = query.Where(r => r.DressId == search.DressId.Value);

        if (search.CustomerUserId.HasValue)
            query = query.Where(r => r.CustomerUserId == search.CustomerUserId.Value);

        if (search.MinRating.HasValue)
            query = query.Where(r => r.Rating >= search.MinRating.Value);

        if (search.MaxRating.HasValue)
            query = query.Where(r => r.Rating <= search.MaxRating.Value);

        if (!string.IsNullOrWhiteSpace(search.FTS))
        {
            var term = search.FTS.Trim().ToLower();
            query = query.Where(r =>
                (r.Title != null && r.Title.ToLower().Contains(term)) ||
                (r.Comment != null && r.Comment.ToLower().Contains(term)));
        }

        return query;
    }

    private async Task<ReviewResponse> LoadAndMapAsync(int id)
    {
        var review = await BuildBaseQuery().FirstAsync(r => r.Id == id);
        return MapToResponse(review);
    }

    private static ReviewResponse MapToResponse(Review entity)
    {
        return new ReviewResponse
        {
            Id = entity.Id,
            DressId = entity.DressId,
            DressName = entity.Dress?.Name ?? string.Empty,
            DressCode = entity.Dress?.Code ?? string.Empty,
            CustomerUserId = entity.CustomerUserId,
            CustomerName = entity.Customer != null
                ? $"{entity.Customer.FirstName} {entity.Customer.LastName}".Trim()
                : string.Empty,
            RentalReservationId = entity.RentalReservationId,
            Rating = entity.Rating,
            Title = entity.Title,
            Comment = entity.Comment,
            Status = entity.Status,
            StatusLabel = entity.Status.ToString(),
            ModerationNote = entity.ModerationNote,
            StaffReply = entity.StaffReply,
            PublishedAtUtc = entity.PublishedAtUtc,
            HiddenAtUtc = entity.HiddenAtUtc,
            CreatedAtUtc = entity.CreatedAtUtc,
            UpdatedAtUtc = entity.UpdatedAtUtc
        };
    }

    private static void NormalizePagination(ReviewSearchObject search)
    {
        const int maxPageSize = 100;
        if (!search.PageSize.HasValue || search.PageSize.Value <= 0)
            search.PageSize = 30;
        if (search.PageSize.Value > maxPageSize)
            search.PageSize = maxPageSize;
        if (!search.Page.HasValue || search.Page.Value < 0)
            search.Page = 0;
    }

    private async Task<Review> GetReviewOrThrowAsync(int id)
    {
        var review = await _context.Reviews
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (review == null)
            throw new UserException("Recenzija nije pronađena.");

        return review;
    }

    private async Task RecalculateDressRatingAsync(int dressId)
    {
        var dress = await _context.Dresses
            .FirstOrDefaultAsync(d => d.Id == dressId && !d.IsDeleted);

        if (dress == null)
            return;

        var publishedRatings = await _context.Reviews
            .Where(r => r.DressId == dressId
                     && r.Status == ReviewStatus.Published
                     && !r.IsDeleted)
            .Select(r => r.Rating)
            .ToListAsync();

        dress.RatingCount = publishedRatings.Count;
        dress.AverageRating = publishedRatings.Count > 0
            ? Math.Round((decimal)publishedRatings.Sum() / publishedRatings.Count, 2)
            : 0m;

        dress.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }
}
