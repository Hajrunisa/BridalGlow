using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public class NotificationService : INotificationService
{
    private readonly BridalGlowDbContext _context;

    public NotificationService(BridalGlowDbContext context)
    {
        _context = context;
    }

    // ── Read ──────────────────────────────────────────────────────────────────

    public async Task<PagedResult<NotificationResponse>> GetMyNotificationsAsync(
        int userId, NotificationSearchObject search)
    {
        NormalizePagination(search);

        var query = _context.Notifications
            .Where(n => n.UserId == userId && !n.IsDeleted);

        if (search.IsRead.HasValue)
        {
            query = search.IsRead.Value
                ? query.Where(n => n.Status == NotificationStatus.Read)
                : query.Where(n => n.Status != NotificationStatus.Read);
        }

        if (search.FromDate.HasValue)
            query = query.Where(n => n.CreatedAtUtc >= search.FromDate.Value);

        if (search.ToDate.HasValue)
            query = query.Where(n => n.CreatedAtUtc <= search.ToDate.Value);

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

        var list = await query.OrderByDescending(n => n.CreatedAtUtc).ToListAsync();

        return new PagedResult<NotificationResponse>
        {
            Items = list.Select(MapToResponse).ToList(),
            TotalCount = totalCount
        };
    }

    // ── Mark as Read ──────────────────────────────────────────────────────────

    public async Task<NotificationResponse> MarkAsReadAsync(int id, int userId)
    {
        var notification = await _context.Notifications
            .FirstOrDefaultAsync(n => n.Id == id && n.UserId == userId && !n.IsDeleted);

        if (notification == null)
            throw new UserException("Notifikacija nije pronađena.");

        if (notification.Status != NotificationStatus.Read)
        {
            var now = DateTime.UtcNow;
            notification.Status = NotificationStatus.Read;
            notification.ReadAtUtc = now;
            notification.UpdatedAtUtc = now;
            await _context.SaveChangesAsync();
        }

        return MapToResponse(notification);
    }

    public async Task MarkAllAsReadAsync(int userId)
    {
        var unread = await _context.Notifications
            .Where(n => n.UserId == userId
                     && n.Status != NotificationStatus.Read
                     && !n.IsDeleted)
            .ToListAsync();

        if (unread.Count == 0) return;

        var now = DateTime.UtcNow;
        foreach (var n in unread)
        {
            n.Status = NotificationStatus.Read;
            n.ReadAtUtc = now;
            n.UpdatedAtUtc = now;
        }

        await _context.SaveChangesAsync();
    }

    // ── Create ────────────────────────────────────────────────────────────────

    public async Task CreateAsync(
        int userId,
        string title,
        string body,
        NotificationType type,
        string? relatedEntityType = null,
        int? relatedEntityId = null)
    {
        var notification = new Notification
        {
            UserId = userId,
            Title = title,
            Body = body,
            Type = type,
            Channel = NotificationChannel.InApp,
            Status = NotificationStatus.Delivered,
            RelatedEntityType = relatedEntityType,
            RelatedEntityId = relatedEntityId,
            CreatedAtUtc = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.Notifications.Add(notification);
        await _context.SaveChangesAsync();
    }

    // ── Worker delivery (async pipeline) ──────────────────────────────────────

    public async Task<bool> ExistsForDeliveryAsync(
        int userId,
        NotificationType type,
        string? relatedEntityType,
        int? relatedEntityId)
    {
        if (string.IsNullOrWhiteSpace(relatedEntityType) || !relatedEntityId.HasValue)
            return false;

        return await _context.Notifications.AnyAsync(n =>
            n.UserId == userId &&
            n.Type == type &&
            n.RelatedEntityType == relatedEntityType &&
            n.RelatedEntityId == relatedEntityId &&
            !n.IsDeleted);
    }

    public async Task<NotificationResponse?> TryCreateQueuedAsync(
        int userId,
        string title,
        string body,
        NotificationType type,
        NotificationChannel channel,
        string? relatedEntityType = null,
        int? relatedEntityId = null)
    {
        if (await ExistsForDeliveryAsync(userId, type, relatedEntityType, relatedEntityId))
            return null;

        var now = DateTime.UtcNow;
        var notification = new Notification
        {
            UserId = userId,
            Title = title,
            Body = body,
            Type = type,
            Channel = channel,
            Status = NotificationStatus.Queued,
            RelatedEntityType = relatedEntityType,
            RelatedEntityId = relatedEntityId,
            CreatedAtUtc = now,
            IsDeleted = false
        };

        _context.Notifications.Add(notification);
        await _context.SaveChangesAsync();

        return MapToResponse(notification);
    }

    public async Task SetDeliveryStatusAsync(int notificationId, NotificationStatus status, string? error = null)
    {
        var notification = await _context.Notifications
            .FirstOrDefaultAsync(n => n.Id == notificationId && !n.IsDeleted);

        if (notification == null)
            throw new UserException("Notifikacija nije pronađena.");

        var now = DateTime.UtcNow;
        notification.Status = status;
        notification.UpdatedAtUtc = now;

        if (status == NotificationStatus.Sent)
            notification.SentAtUtc = now;

        if (status == NotificationStatus.Failed && !string.IsNullOrWhiteSpace(error))
            notification.PayloadJson = System.Text.Json.JsonSerializer.Serialize(new { deliveryError = error });

        await _context.SaveChangesAsync();
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    private static NotificationResponse MapToResponse(Notification entity) => new()
    {
        Id = entity.Id,
        UserId = entity.UserId,
        Type = entity.Type,
        TypeLabel = entity.Type.ToString(),
        Channel = entity.Channel,
        Title = entity.Title,
        Body = entity.Body,
        Status = entity.Status,
        StatusLabel = entity.Status.ToString(),
        IsRead = entity.Status == NotificationStatus.Read,
        ReadAtUtc = entity.ReadAtUtc,
        RelatedEntityType = entity.RelatedEntityType,
        RelatedEntityId = entity.RelatedEntityId,
        CreatedAtUtc = entity.CreatedAtUtc
    };

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static void NormalizePagination(NotificationSearchObject search)
    {
        const int maxPageSize = 100;
        if (!search.PageSize.HasValue || search.PageSize.Value <= 0)
            search.PageSize = 30;
        if (search.PageSize.Value > maxPageSize)
            search.PageSize = maxPageSize;
        if (!search.Page.HasValue || search.Page.Value < 0)
            search.Page = 0;
    }
}
