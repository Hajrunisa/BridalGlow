using BridalGlow.Data.Database;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Messaging.Messages;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BridalGlow.Worker.Services;

/// <summary>
/// Schedules try-on reminder notifications by enqueueing outbox messages.
/// </summary>
public class TryOnReminderHostedService : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromMinutes(15);
    private static readonly double ReminderLeadHours = 24;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<TryOnReminderHostedService> _logger;

    public TryOnReminderHostedService(
        IServiceScopeFactory scopeFactory,
        ILogger<TryOnReminderHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Try-on reminder scheduler started.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ScheduleRemindersAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Try-on reminder scheduler encountered an error.");
            }

            try
            {
                await Task.Delay(PollInterval, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
        }

        _logger.LogInformation("Try-on reminder scheduler stopped.");
    }

    private async Task ScheduleRemindersAsync(CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<BridalGlowDbContext>();
        var publisher = scope.ServiceProvider.GetRequiredService<IDomainEventPublisher>();

        var now = DateTime.UtcNow;
        var horizon = now.AddHours(ReminderLeadHours);

        var dueReservations = await context.TryOnReservations
            .AsNoTracking()
            .Where(r => !r.IsDeleted && r.Status == TryOnReservationStatus.Confirmed)
            .Where(r => r.StartAtUtc > now && r.StartAtUtc <= horizon)
            .Select(r => new
            {
                r.Id,
                r.CustomerUserId,
                r.ReservationNumber,
                r.StartAtUtc
            })
            .ToListAsync(cancellationToken);

        if (dueReservations.Count == 0)
            return;

        var reservationIds = dueReservations.Select(r => r.Id).ToList();

        var alreadyRemindedIds = await context.Notifications
            .AsNoTracking()
            .Where(n => !n.IsDeleted &&
                        n.Type == NotificationType.TryOnReminder &&
                        n.RelatedEntityType == "TryOnReservation" &&
                        n.RelatedEntityId != null &&
                        reservationIds.Contains(n.RelatedEntityId!.Value))
            .Select(n => n.RelatedEntityId!.Value)
            .ToListAsync(cancellationToken);

        var remindedSet = alreadyRemindedIds.ToHashSet();
        var scheduled = 0;

        foreach (var reservation in dueReservations)
        {
            if (remindedSet.Contains(reservation.Id))
                continue;

            var localStart = reservation.StartAtUtc.ToLocalTime();
            var message = new NotificationRequestedMessage
            {
                UserId = reservation.CustomerUserId,
                Title = "Podsjetnik za probu vjenčanice",
                Body =
                    $"Podsjetnik: Vaša rezervacija za probu {reservation.ReservationNumber} je zakazana za " +
                    $"{localStart:dd.MM.yyyy HH:mm}.",
                Type = NotificationType.TryOnReminder,
                Channel = NotificationChannel.InApp,
                RelatedEntityType = "TryOnReservation",
                RelatedEntityId = reservation.Id,
                SendEmail = false
            };

            await publisher.EnqueueAsync(message, cancellationToken);
            scheduled++;
        }

        if (scheduled > 0)
            _logger.LogInformation("Queued {Count} try-on reminder notification(s).", scheduled);
    }
}
