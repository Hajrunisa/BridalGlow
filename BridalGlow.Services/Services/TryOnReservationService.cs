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

public class TryOnReservationService : ITryOnReservationService
{
    private readonly BridalGlowDbContext _context;
    private readonly IDomainNotificationPublisher _domainNotifications;
    private readonly IUserDressInteractionService _interactionService;
    private readonly ILogger<TryOnReservationService> _logger;

    public TryOnReservationService(
        BridalGlowDbContext context,
        IDomainNotificationPublisher domainNotifications,
        IUserDressInteractionService interactionService,
        ILogger<TryOnReservationService> logger)
    {
        _context = context;
        _domainNotifications = domainNotifications;
        _interactionService = interactionService;
        _logger = logger;
    }

    // ── Read (Staff/Admin) ────────────────────────────────────────────────────

    public async Task<PagedResult<TryOnReservationResponse>> GetAsync(TryOnReservationSearchObject search)
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

        var list = await query.OrderByDescending(r => r.CreatedAtUtc).ToListAsync();
        return new PagedResult<TryOnReservationResponse>
        {
            Items = list.Select(r => MapToResponse(r, includeHistory: false)).ToList(),
            TotalCount = totalCount
        };
    }

    public async Task<TryOnReservationResponse?> GetByIdAsync(int id)
    {
        var entity = await BuildBaseQuery()
            .Include(r => r.StatusHistory)
                .ThenInclude(h => h.ChangedByUser)
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        return entity == null ? null : MapToResponse(entity, includeHistory: true);
    }

    // ── Read (Customer: own reservations) ─────────────────────────────────────

    public async Task<PagedResult<TryOnReservationResponse>> GetMyReservationsAsync(
        int customerId, TryOnReservationSearchObject search)
    {
        NormalizePagination(search);

        var query = BuildBaseQuery().Where(r => r.CustomerUserId == customerId);
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

        var list = await query.OrderByDescending(r => r.CreatedAtUtc).ToListAsync();
        return new PagedResult<TryOnReservationResponse>
        {
            Items = list.Select(r => MapToResponse(r, includeHistory: false)).ToList(),
            TotalCount = totalCount
        };
    }

    // ── Create ────────────────────────────────────────────────────────────────

    public async Task<TryOnReservationResponse> CreateAsync(
        int customerId, TryOnReservationCreateRequest request)
    {
        await ValidateCreateRequestAsync(request);

        // Load and verify the selected availability slot
        var slot = await _context.DressAvailabilitySlots
            .FirstOrDefaultAsync(s => s.Id == request.AvailabilitySlotId
                                   && s.DressId == request.DressId
                                   && s.SlotType == AvailabilitySlotType.Available
                                   && !s.IsDeleted);

        if (slot == null)
            throw new UserException("Odabrani termin nije pronađen ili više nije dostupan.");

        // Determine the effective appointment window.
        // When the Available slot spans multiple days (e.g. a full month for Rental
        // availability) and the customer is booking a specific day for Try-On,
        // we restrict the TryOnHold to just that day so the remaining days in the
        // slot stay available for other customers.
        DateTime holdStart, holdEnd;
        if (request.AppointmentDate.HasValue)
        {
            var apptDayStart = request.AppointmentDate.Value.Date.ToUniversalTime();
            var apptDayEnd   = apptDayStart.AddDays(1);
            holdStart = slot.StartAtUtc < apptDayStart ? apptDayStart : slot.StartAtUtc;
            holdEnd   = slot.EndAtUtc   > apptDayEnd   ? apptDayEnd   : slot.EndAtUtc;
        }
        else
        {
            holdStart = slot.StartAtUtc;
            holdEnd   = slot.EndAtUtc;
        }

        // Double-check no blocking slot overlaps the effective appointment window
        // (race-condition guard). We check against holdStart/holdEnd — not the full
        // Available slot span — so a RentalHold on unrelated days does not block this booking.
        var hasConflict = await _context.DressAvailabilitySlots
            .AnyAsync(s => s.DressId == request.DressId
                        && !s.IsDeleted
                        && s.Id != slot.Id
                        && s.SlotType != AvailabilitySlotType.Available
                        && s.StartAtUtc < holdEnd
                        && s.EndAtUtc   > holdStart);

        if (hasConflict)
            throw new UserException("Odabrani termin je u međuvremenu zauzet. Molimo odaberite drugi termin.");

        // Get effective price via Pricing Engine
        var effectivePrice = await GetEffectivePriceInternalAsync(request.DressId, holdStart, holdEnd);

        // Load dress for deposit amount
        var dress = await _context.Dresses
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.Id == request.DressId && !d.IsDeleted);

        // Generate unique reservation number
        var reservationNumber = await GenerateUniqueReservationNumberAsync();

        var now = DateTime.UtcNow;

        // Create the TryOnHold slot only for the effective appointment window,
        // NOT for the entire Available slot duration.
        var holdSlot = new DressAvailabilitySlot
        {
            DressId = request.DressId,
            StartAtUtc = holdStart,
            EndAtUtc = holdEnd,
            SlotType = AvailabilitySlotType.TryOnHold,
            Reason = $"Rezervacija {reservationNumber}",
            SourceReservationType = ReservationSourceType.TryOn,
            CreatedAtUtc = now,
            IsDeleted = false
        };
        _context.DressAvailabilitySlots.Add(holdSlot);

        // Create the reservation
        var reservation = new TryOnReservation
        {
            ReservationNumber = reservationNumber,
            DressId = request.DressId,
            CustomerUserId = customerId,
            StartAtUtc = holdStart,
            EndAtUtc = holdEnd,
            Status = TryOnReservationStatus.Pending,
            PriceAmount = effectivePrice,
            DepositAmount = dress?.TryOnPrice,
            Notes = request.Notes?.Trim(),
            CreatedAtUtc = now,
            IsDeleted = false
        };
        _context.TryOnReservations.Add(reservation);

        // Save so we get the reservation ID for back-linking the hold slot
        await _context.SaveChangesAsync();

        // Back-link the hold slot to this reservation
        holdSlot.SourceReservationId = reservation.Id;
        reservation.UpdatedAtUtc = now;

        // Create initial status history entry
        var historyEntry = new TryOnReservationStatusHistory
        {
            TryOnReservationId = reservation.Id,
            ChangedByUserId = customerId,
            FromStatus = TryOnReservationStatus.Pending,
            ToStatus = TryOnReservationStatus.Pending,
            ChangedAtUtc = now,
            Reason = "Rezervacija kreirana"
        };
        _context.TryOnReservationStatusHistories.Add(historyEntry);

        await _domainNotifications.StageStaffOperationalNotificationsAsync(
            "Nova try-on rezervacija",
            $"Nova try-on rezervacija {reservationNumber} je kreirana i čeka potvrdu.",
            NotificationType.ReservationStatusChanged,
            relatedEntityType: "TryOnReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        await TryRecordTryOnReservedInteractionAsync(
            customerId,
            reservation.DressId,
            reservation.Id);

        return (await GetByIdAsync(reservation.Id))!;
    }

    // ── Cancel ────────────────────────────────────────────────────────────────

    public async Task<TryOnReservationResponse> CancelAsync(
        int id, int userId, bool isStaff, TryOnReservationCancelRequest request)
    {
        var reservation = await _context.TryOnReservations
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (reservation == null)
            throw new UserException("Rezervacija nije pronađena.");

        // Only the customer who made it (or staff) can cancel
        if (!isStaff && reservation.CustomerUserId != userId)
            throw new UserException("Nemate dozvolu za otkazivanje ove rezervacije.");

        // Validate current status allows cancellation
        var cancellableStatuses = new[]
        {
            TryOnReservationStatus.Pending,
            TryOnReservationStatus.Confirmed
        };

        if (!cancellableStatuses.Contains(reservation.Status))
            throw new UserException($"Rezervacija sa statusom '{reservation.Status}' ne može biti otkazana.");

        var previousStatus = reservation.Status;
        var newStatus = isStaff ? TryOnReservationStatus.CancelledByStaff : TryOnReservationStatus.CancelledByCustomer;
        var now = DateTime.UtcNow;

        // Free the TryOnHold slot
        await ReleaseTryOnHoldSlotAsync(reservation.Id);

        // Update reservation
        reservation.Status = newStatus;
        reservation.CancellationReason = request.Reason?.Trim();
        reservation.CancelledAtUtc = now;
        reservation.UpdatedAtUtc = now;

        // Record status history
        _context.TryOnReservationStatusHistories.Add(new TryOnReservationStatusHistory
        {
            TryOnReservationId = reservation.Id,
            ChangedByUserId = userId,
            FromStatus = previousStatus,
            ToStatus = newStatus,
            ChangedAtUtc = now,
            Reason = request.Reason?.Trim()
        });

        var cancelBody = isStaff
            ? $"Vaša rezervacija {reservation.ReservationNumber} je otkazana od strane osoblja."
            : $"Vaša rezervacija {reservation.ReservationNumber} je uspješno otkazana.";
        _domainNotifications.StageCustomerNotification(
            reservation.CustomerUserId,
            "Rezervacija otkazana",
            cancelBody,
            NotificationType.ReservationStatusChanged,
            relatedEntityType: "TryOnReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        return (await GetByIdAsync(reservation.Id))!;
    }

    // ── Confirm (Staff) ───────────────────────────────────────────────────────

    public async Task<TryOnReservationResponse> ConfirmAsync(
        int id, int staffUserId, TryOnReservationStatusChangeRequest request)
    {
        var reservation = await _context.TryOnReservations
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (reservation == null)
            throw new UserException("Rezervacija nije pronađena.");

        if (reservation.Status != TryOnReservationStatus.Pending)
            throw new UserException($"Samo rezervacije sa statusom 'Pending' mogu biti potvrđene. Trenutni status: {reservation.Status}.");

        var now = DateTime.UtcNow;

        _context.TryOnReservationStatusHistories.Add(new TryOnReservationStatusHistory
        {
            TryOnReservationId = reservation.Id,
            ChangedByUserId = staffUserId,
            FromStatus = reservation.Status,
            ToStatus = TryOnReservationStatus.Confirmed,
            ChangedAtUtc = now,
            Reason = request.Reason?.Trim()
        });

        reservation.Status = TryOnReservationStatus.Confirmed;
        reservation.ConfirmedAtUtc = now;
        reservation.UpdatedAtUtc = now;

        _domainNotifications.StageCustomerNotification(
            reservation.CustomerUserId,
            "Rezervacija potvrđena",
            $"Vaša rezervacija {reservation.ReservationNumber} je uspješno potvrđena. Radujemo se Vašem dolasku!",
            NotificationType.ReservationStatusChanged,
            relatedEntityType: "TryOnReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        await TryRecordTryOnReservedInteractionAsync(
            reservation.CustomerUserId,
            reservation.DressId,
            reservation.Id);

        return (await GetByIdAsync(reservation.Id))!;
    }

    // ── Complete (Staff) ──────────────────────────────────────────────────────

    public async Task<TryOnReservationResponse> CompleteAsync(
        int id, int staffUserId, TryOnReservationStatusChangeRequest request)
    {
        var reservation = await _context.TryOnReservations
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (reservation == null)
            throw new UserException("Rezervacija nije pronađena.");

        var completableStatuses = new[]
        {
            TryOnReservationStatus.Confirmed,
            TryOnReservationStatus.CheckedIn
        };

        if (!completableStatuses.Contains(reservation.Status))
            throw new UserException($"Rezervacija sa statusom '{reservation.Status}' ne može biti označena kao završena.");

        var now = DateTime.UtcNow;

        _context.TryOnReservationStatusHistories.Add(new TryOnReservationStatusHistory
        {
            TryOnReservationId = reservation.Id,
            ChangedByUserId = staffUserId,
            FromStatus = reservation.Status,
            ToStatus = TryOnReservationStatus.Completed,
            ChangedAtUtc = now,
            Reason = request.Reason?.Trim()
        });

        reservation.Status = TryOnReservationStatus.Completed;
        reservation.CompletedAtUtc = now;
        reservation.UpdatedAtUtc = now;

        _domainNotifications.StageCustomerNotification(
            reservation.CustomerUserId,
            "Proba haljine završena",
            $"Proba haljine za rezervaciju {reservation.ReservationNumber} je uspješno završena. Hvala na posjeti!",
            NotificationType.ReservationStatusChanged,
            relatedEntityType: "TryOnReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        return (await GetByIdAsync(reservation.Id))!;
    }

    // ── NoShow (Staff) ────────────────────────────────────────────────────────

    public async Task<TryOnReservationResponse> MarkNoShowAsync(
        int id, int staffUserId, TryOnReservationStatusChangeRequest request)
    {
        var reservation = await _context.TryOnReservations
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (reservation == null)
            throw new UserException("Rezervacija nije pronađena.");

        if (reservation.Status != TryOnReservationStatus.Confirmed)
            throw new UserException($"Samo potvrđene rezervacije mogu biti označene kao NoShow. Trenutni status: {reservation.Status}.");

        var now = DateTime.UtcNow;

        _context.TryOnReservationStatusHistories.Add(new TryOnReservationStatusHistory
        {
            TryOnReservationId = reservation.Id,
            ChangedByUserId = staffUserId,
            FromStatus = reservation.Status,
            ToStatus = TryOnReservationStatus.NoShow,
            ChangedAtUtc = now,
            Reason = request.Reason?.Trim()
        });

        reservation.Status = TryOnReservationStatus.NoShow;
        reservation.NoShowAtUtc = now;
        reservation.UpdatedAtUtc = now;

        _domainNotifications.StageCustomerNotification(
            reservation.CustomerUserId,
            "Propuštena proba",
            $"Niste se pojavili na zakazanoj probi za rezervaciju {reservation.ReservationNumber}.",
            NotificationType.ReservationStatusChanged,
            relatedEntityType: "TryOnReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        return (await GetByIdAsync(reservation.Id))!;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private IQueryable<TryOnReservation> BuildBaseQuery()
    {
        return _context.TryOnReservations
            .Include(r => r.Dress)
            .Include(r => r.Customer)
            .Where(r => !r.IsDeleted);
    }

    private static IQueryable<TryOnReservation> ApplyFilter(
        IQueryable<TryOnReservation> query, TryOnReservationSearchObject search)
    {
        if (search.Status.HasValue)
            query = query.Where(r => r.Status == search.Status.Value);

        if (search.DressId.HasValue)
            query = query.Where(r => r.DressId == search.DressId.Value);

        if (search.CustomerUserId.HasValue)
            query = query.Where(r => r.CustomerUserId == search.CustomerUserId.Value);

        if (search.FromDate.HasValue)
            query = query.Where(r => r.StartAtUtc >= search.FromDate.Value);

        if (search.ToDate.HasValue)
            query = query.Where(r => r.StartAtUtc <= search.ToDate.Value);

        return query;
    }

    private async Task ValidateCreateRequestAsync(TryOnReservationCreateRequest request)
    {
        if (request.DressId <= 0)
            throw new UserException("DressId je obavezan.");

        if (request.AvailabilitySlotId <= 0)
            throw new UserException("AvailabilitySlotId je obavezan.");

        var dressExists = await _context.Dresses
            .AnyAsync(d => d.Id == request.DressId && !d.IsDeleted);
        if (!dressExists)
            throw new UserException("Odabrana vjenčanica ne postoji ili je obrisana.");
    }

    private async Task ReleaseTryOnHoldSlotAsync(int reservationId)
    {
        var holdSlot = await _context.DressAvailabilitySlots
            .FirstOrDefaultAsync(s => s.SourceReservationId == reservationId
                                   && s.SourceReservationType == ReservationSourceType.TryOn
                                   && s.SlotType == AvailabilitySlotType.TryOnHold
                                   && !s.IsDeleted);

        if (holdSlot != null)
        {
            holdSlot.IsDeleted = true;
            holdSlot.UpdatedAtUtc = DateTime.UtcNow;
        }
    }

    private async Task<decimal> GetEffectivePriceInternalAsync(int dressId, DateTime startAt, DateTime endAt)
    {
        var dress = await _context.Dresses
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.Id == dressId && !d.IsDeleted);

        if (dress == null)
            throw new UserException("Odabrana vjenčanica ne postoji.");

        // Use dress.TryOnPrice if set, otherwise fall back to pricing rules / base price
        if (dress.TryOnPrice.HasValue)
            return dress.TryOnPrice.Value;

        var rules = await _context.DressPriceRules
            .Where(r => r.DressId == dressId
                     && !r.IsDeleted
                     && r.IsActive
                     && r.StartDateUtc <= endAt
                     && (r.EndDateUtc == null || r.EndDateUtc >= startAt))
            .OrderByDescending(r => r.Priority)
            .ToListAsync();

        if (rules.Count == 0)
            return dress.BaseRentalPrice;

        // Apply best matching rule (Weekend rules require a weekend day in range)
        DressPriceRule? appliedRule = null;
        foreach (var rule in rules)
        {
            if (rule.RuleType == PriceRuleType.Weekend && !PeriodContainsWeekend(startAt, endAt))
                continue;
            appliedRule = rule;
            break;
        }

        if (appliedRule == null)
            return dress.BaseRentalPrice;

        return appliedRule.Percent.HasValue
            ? Math.Round(dress.BaseRentalPrice * (1m - appliedRule.Percent.Value / 100m), 2)
            : appliedRule.Amount;
    }

    private static bool PeriodContainsWeekend(DateTime startUtc, DateTime endUtc)
    {
        for (var d = startUtc.Date; d <= endUtc.Date; d = d.AddDays(1))
        {
            if (d.DayOfWeek == DayOfWeek.Saturday || d.DayOfWeek == DayOfWeek.Sunday)
                return true;
        }
        return false;
    }

    private async Task<string> GenerateUniqueReservationNumberAsync()
    {
        string number;
        bool exists;
        do
        {
            var date = DateTime.UtcNow.ToString("yyyyMMdd");
            var suffix = Guid.NewGuid().ToString("N")[..6].ToUpper();
            number = $"TRY-{date}-{suffix}";
            exists = await _context.TryOnReservations.AnyAsync(r => r.ReservationNumber == number);
        } while (exists);

        return number;
    }

    private static void NormalizePagination(TryOnReservationSearchObject search)
    {
        const int maxPageSize = 100;
        if (!search.PageSize.HasValue || search.PageSize.Value <= 0)
            search.PageSize = 30;
        if (search.PageSize.Value > maxPageSize)
            search.PageSize = maxPageSize;
        if (!search.Page.HasValue || search.Page.Value < 0)
            search.Page = 0;
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    private static TryOnReservationResponse MapToResponse(TryOnReservation entity, bool includeHistory)
    {
        var response = new TryOnReservationResponse
        {
            Id = entity.Id,
            ReservationNumber = entity.ReservationNumber,
            DressId = entity.DressId,
            DressName = entity.Dress?.Name ?? string.Empty,
            DressCode = entity.Dress?.Code ?? string.Empty,
            CustomerUserId = entity.CustomerUserId,
            CustomerName = entity.Customer != null
                ? $"{entity.Customer.FirstName} {entity.Customer.LastName}".Trim()
                : string.Empty,
            CustomerEmail = entity.Customer?.Email ?? string.Empty,
            StartAtUtc = entity.StartAtUtc,
            EndAtUtc = entity.EndAtUtc,
            Status = entity.Status,
            StatusLabel = entity.Status.ToString(),
            PriceAmount = entity.PriceAmount,
            DepositAmount = entity.DepositAmount,
            Notes = entity.Notes,
            CancellationReason = entity.CancellationReason,
            CancelledAtUtc = entity.CancelledAtUtc,
            ConfirmedAtUtc = entity.ConfirmedAtUtc,
            CompletedAtUtc = entity.CompletedAtUtc,
            NoShowAtUtc = entity.NoShowAtUtc,
            CreatedAtUtc = entity.CreatedAtUtc,
            UpdatedAtUtc = entity.UpdatedAtUtc
        };

        if (includeHistory && entity.StatusHistory != null)
        {
            response.StatusHistory = entity.StatusHistory
                .OrderBy(h => h.ChangedAtUtc)
                .Select(h => new TryOnReservationStatusHistoryResponse
                {
                    Id = h.Id,
                    FromStatus = h.FromStatus,
                    FromStatusLabel = h.FromStatus.ToString(),
                    ToStatus = h.ToStatus,
                    ToStatusLabel = h.ToStatus.ToString(),
                    ChangedByUserId = h.ChangedByUserId,
                    ChangedByUserName = h.ChangedByUser != null
                        ? $"{h.ChangedByUser.FirstName} {h.ChangedByUser.LastName}".Trim()
                        : string.Empty,
                    ChangedAtUtc = h.ChangedAtUtc,
                    Reason = h.Reason
                })
                .ToList();
        }

        return response;
    }

    private async Task TryRecordTryOnReservedInteractionAsync(
        int customerUserId,
        int dressId,
        int tryOnReservationId)
    {
        try
        {
            await _interactionService.RecordInteractionAsync(
                customerUserId,
                dressId,
                InteractionType.TryOnReserved,
                InteractionSource.System,
                metadataJson: UserDressInteractionService.BuildReservationMetadata(
                    "tryOnReservationId",
                    tryOnReservationId));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                ex,
                "Neuspješan zapis TryOnReserved interakcije (user {UserId}, dress {DressId}, reservation {ReservationId}).",
                customerUserId,
                dressId,
                tryOnReservationId);
        }
    }
}
