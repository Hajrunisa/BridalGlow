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

public class RentalReservationService : IRentalReservationService
{
    private readonly BridalGlowDbContext _context;
    private readonly IDressPriceRuleService _priceRuleService;
    private readonly IDressAvailabilitySlotService _availabilitySlotService;
    private readonly IDomainNotificationPublisher _domainNotifications;
    private readonly IUserDressInteractionService _interactionService;
    private readonly ILogger<RentalReservationService> _logger;

    public RentalReservationService(
        BridalGlowDbContext context,
        IDressPriceRuleService priceRuleService,
        IDressAvailabilitySlotService availabilitySlotService,
        IDomainNotificationPublisher domainNotifications,
        IUserDressInteractionService interactionService,
        ILogger<RentalReservationService> logger)
    {
        _context = context;
        _priceRuleService = priceRuleService;
        _availabilitySlotService = availabilitySlotService;
        _domainNotifications = domainNotifications;
        _interactionService = interactionService;
        _logger = logger;
    }

    // ── Read (Staff/Admin) ────────────────────────────────────────────────────

    public async Task<PagedResult<RentalReservationResponse>> GetAsync(RentalReservationSearchObject search)
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
        return new PagedResult<RentalReservationResponse>
        {
            Items = list.Select(r => MapToResponse(r, includeHistory: false)).ToList(),
            TotalCount = totalCount
        };
    }

    public async Task<RentalReservationResponse?> GetByIdAsync(
        int id, int? requestingUserId = null, bool isStaff = false)
    {
        var entity = await BuildBaseQuery()
            .Include(r => r.StatusHistory)
                .ThenInclude(h => h.ChangedByUser)
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (entity == null)
            return null;

        if (!isStaff && requestingUserId.HasValue && entity.CustomerUserId != requestingUserId.Value)
            throw new UserException("Nemate dozvolu za pregled ove rezervacije.");

        return MapToResponse(entity, includeHistory: true);
    }

    // ── Read (Customer: own reservations) ─────────────────────────────────────

    public async Task<PagedResult<RentalReservationResponse>> GetMineAsync(
        int customerId, RentalReservationSearchObject search)
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
        return new PagedResult<RentalReservationResponse>
        {
            Items = list.Select(r => MapToResponse(r, includeHistory: false)).ToList(),
            TotalCount = totalCount
        };
    }

    // ── Create ────────────────────────────────────────────────────────────────

    public async Task<RentalReservationResponse> CreateAsync(
        int customerId, RentalReservationCreateRequest request)
    {
        await ValidateCreateRequestAsync(customerId, request);

        var dress = await _context.Dresses
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.Id == request.DressId && !d.IsDeleted);

        if (dress == null)
            throw new UserException("Odabrana vjenčanica ne postoji ili je obrisana.");

        if (dress.Status != DressStatus.Active)
            throw new UserException("Odabrana vjenčanica nije dostupna za iznajmljivanje.");

        var startUtc = NormalizeToUtc(request.StartDateUtc);
        var endUtc = NormalizeToUtc(request.EndDateUtc);

        // Check date range
        if (startUtc.Date < DateTime.UtcNow.Date)
            throw new UserException("Datum početka iznajmljivanja ne može biti u prošlosti.");

        if (endUtc <= startUtc)
            throw new UserException("Datum završetka mora biti nakon datuma početka.");

        if ((endUtc.Date - startUtc.Date).TotalDays < 1)
            throw new UserException("Minimalni period iznajmljivanja je jedan dan.");

        // Validate availability using the same day-level rules as the mobile calendar.
        await _availabilitySlotService.ValidateRentalPeriodAsync(request.DressId, startUtc, endUtc);

        // Calculate effective price via DressPriceRuleService
        var priceResult = await _priceRuleService.GetEffectivePriceAsync(request.DressId, startUtc, endUtc);
        var baseAmount = priceResult.BaseRentalPrice;
        var effectivePrice = priceResult.EffectivePrice;
        var discountAmount = Math.Max(0m, baseAmount - effectivePrice);
        var depositAmount = dress.DepositAmount ?? 0m;

        var reservationNumber = await GenerateUniqueReservationNumberAsync();
        var now = DateTime.UtcNow;

        // Create the RentalHold slot to block the period
        var holdSlot = new DressAvailabilitySlot
        {
            DressId = request.DressId,
            StartAtUtc = startUtc,
            EndAtUtc = endUtc,
            SlotType = AvailabilitySlotType.RentalHold,
            Reason = $"Rezervacija {reservationNumber}",
            SourceReservationType = ReservationSourceType.Rental,
            CreatedAtUtc = now,
            IsDeleted = false
        };
        _context.DressAvailabilitySlots.Add(holdSlot);

        // Create the reservation
        var reservation = new RentalReservation
        {
            ReservationNumber = reservationNumber,
            DressId = request.DressId,
            CustomerUserId = customerId,
            StartDateUtc = startUtc,
            EndDateUtc = endUtc,
            Status = RentalReservationStatus.Pending,
            BaseAmount = baseAmount,
            DiscountAmount = discountAmount,
            DepositAmount = depositAmount,
            LateFeeAmount = 0m,
            DamageFeeAmount = 0m,
            TotalAmount = effectivePrice,
            Currency = "EUR",
            Notes = request.Notes?.Trim(),
            CreatedAtUtc = now,
            IsDeleted = false
        };
        _context.RentalReservations.Add(reservation);

        // Save to get the reservation ID for back-linking the hold slot
        await _context.SaveChangesAsync();

        holdSlot.SourceReservationId = reservation.Id;
        reservation.UpdatedAtUtc = now;

        // Create initial status history entry
        var historyEntry = new RentalReservationStatusHistory
        {
            RentalReservationId = reservation.Id,
            ChangedByUserId = customerId,
            FromStatus = RentalReservationStatus.Pending,
            ToStatus = RentalReservationStatus.Pending,
            ChangedAtUtc = now,
            Reason = "Rental rezervacija kreirana"
        };
        _context.RentalReservationStatusHistories.Add(historyEntry);

        await _domainNotifications.StageStaffOperationalNotificationsAsync(
            "Nova rental rezervacija",
            $"Nova rental rezervacija {reservationNumber} je kreirana i čeka odobrenje.",
            NotificationType.ReservationStatusChanged,
            relatedEntityType: "RentalReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        await TryRecordRentalReservedInteractionAsync(
            customerId,
            reservation.DressId,
            reservation.Id);

        return (await GetByIdAsync(reservation.Id, isStaff: true))!;
    }

    // ── Cancel ────────────────────────────────────────────────────────────────

    public async Task<RentalReservationResponse> CancelAsync(
        int id, int userId, bool isStaff, RentalReservationCancelRequest request)
    {
        var reservation = await _context.RentalReservations
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (reservation == null)
            throw new UserException("Rezervacija nije pronađena.");

        if (!isStaff && reservation.CustomerUserId != userId)
            throw new UserException("Nemate dozvolu za otkazivanje ove rezervacije.");

        RentalReservationStatus newStatus;

        if (isStaff)
        {
            var staffCancellable = new[]
            {
                RentalReservationStatus.Pending,
                RentalReservationStatus.Approved,
                RentalReservationStatus.AwaitingPayment,
                RentalReservationStatus.Paid
            };
            if (!staffCancellable.Contains(reservation.Status))
                throw new UserException($"Rezervacija sa statusom '{reservation.Status}' ne može biti otkazana od strane osoblja.");

            newStatus = RentalReservationStatus.CancelledByStaff;
        }
        else
        {
            if (reservation.Status != RentalReservationStatus.Pending)
                throw new UserException("Kupac može otkazati samo rezervacije sa statusom 'Pending'.");

            newStatus = RentalReservationStatus.CancelledByCustomer;
        }

        var previousStatus = reservation.Status;
        var now = DateTime.UtcNow;

        // Release the RentalHold slot
        await ReleaseRentalHoldSlotAsync(reservation.Id);

        // Update reservation
        reservation.Status = newStatus;
        reservation.CancellationReason = request.Reason?.Trim();
        reservation.CancelledAtUtc = now;
        reservation.UpdatedAtUtc = now;

        // Record status history
        _context.RentalReservationStatusHistories.Add(new RentalReservationStatusHistory
        {
            RentalReservationId = reservation.Id,
            ChangedByUserId = userId,
            FromStatus = previousStatus,
            ToStatus = newStatus,
            ChangedAtUtc = now,
            Reason = request.Reason?.Trim()
        });

        var cancelBody = isStaff
            ? $"Vaša rental rezervacija {reservation.ReservationNumber} je otkazana od strane osoblja."
            : $"Vaša rental rezervacija {reservation.ReservationNumber} je uspješno otkazana.";

        _domainNotifications.StageCustomerNotification(
            reservation.CustomerUserId,
            "Rental rezervacija otkazana",
            cancelBody,
            NotificationType.ReservationStatusChanged,
            relatedEntityType: "RentalReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        return (await GetByIdAsync(reservation.Id, isStaff: true))!;
    }

    // ── Staff lifecycle ───────────────────────────────────────────────────────

    public async Task<RentalReservationResponse> ApproveAsync(int id, int staffUserId)
    {
        var reservation = await GetReservationOrThrowAsync(id);

        if (reservation.Status != RentalReservationStatus.Pending)
            throw new UserException($"Samo rezervacije sa statusom 'Pending' mogu biti odobrene. Trenutni status: {reservation.Status}.");

        var now = DateTime.UtcNow;
        var previousStatus = reservation.Status;

        reservation.Status = RentalReservationStatus.Approved;
        reservation.ApprovedAtUtc = now;
        reservation.UpdatedAtUtc = now;

        AddStatusHistory(reservation.Id, staffUserId, previousStatus, RentalReservationStatus.Approved, now);

        _domainNotifications.StageCustomerNotification(
            reservation.CustomerUserId,
            "Rental rezervacija odobrena",
            $"Vaša rental rezervacija {reservation.ReservationNumber} je odobrena.",
            NotificationType.RentalApproved,
            relatedEntityType: "RentalReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        await TryRecordRentalReservedInteractionAsync(
            reservation.CustomerUserId,
            reservation.DressId,
            reservation.Id);

        return (await GetByIdAsync(reservation.Id, isStaff: true))!;
    }

    public async Task<RentalReservationResponse> RejectAsync(
        int id, int staffUserId, RentalReservationStatusChangeRequest request)
    {
        var reservation = await GetReservationOrThrowAsync(id);

        if (reservation.Status != RentalReservationStatus.Pending)
            throw new UserException($"Samo rezervacije sa statusom 'Pending' mogu biti odbijene. Trenutni status: {reservation.Status}.");

        var now = DateTime.UtcNow;
        var previousStatus = reservation.Status;

        await ReleaseRentalHoldSlotAsync(reservation.Id);

        reservation.Status = RentalReservationStatus.Rejected;
        reservation.CancellationReason = request.Reason?.Trim();
        reservation.UpdatedAtUtc = now;

        AddStatusHistory(reservation.Id, staffUserId, previousStatus, RentalReservationStatus.Rejected, now, request.Reason?.Trim());

        _domainNotifications.StageCustomerNotification(
            reservation.CustomerUserId,
            "Rental rezervacija odbijena",
            $"Vaša rental rezervacija {reservation.ReservationNumber} je odbijena." +
                (string.IsNullOrWhiteSpace(request.Reason) ? string.Empty : $" Razlog: {request.Reason.Trim()}"),
            NotificationType.RentalRejected,
            relatedEntityType: "RentalReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        return (await GetByIdAsync(reservation.Id, isStaff: true))!;
    }

    public async Task<RentalReservationResponse> MarkReadyForPickupAsync(int id, int staffUserId)
    {
        var reservation = await GetReservationOrThrowAsync(id);

        if (reservation.Status != RentalReservationStatus.Paid)
            throw new UserException($"Samo plaćene rezervacije mogu biti označene kao spremne za preuzimanje. Trenutni status: {reservation.Status}.");

        var now = DateTime.UtcNow;
        var previousStatus = reservation.Status;

        reservation.Status = RentalReservationStatus.ReadyForPickup;
        reservation.UpdatedAtUtc = now;

        AddStatusHistory(reservation.Id, staffUserId, previousStatus, RentalReservationStatus.ReadyForPickup, now);

        _domainNotifications.StageCustomerNotification(
            reservation.CustomerUserId,
            "Vjenčanica je spremna za preuzimanje",
            $"Vaša rental rezervacija {reservation.ReservationNumber} — vjenčanica je spremna za preuzimanje.",
            NotificationType.RentalReadyForPickup,
            relatedEntityType: "RentalReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        return (await GetByIdAsync(reservation.Id, isStaff: true))!;
    }

    public async Task<RentalReservationResponse> MarkPickedUpAsync(int id, int staffUserId)
    {
        var reservation = await GetReservationOrThrowAsync(id);

        if (reservation.Status != RentalReservationStatus.ReadyForPickup)
            throw new UserException($"Samo rezervacije sa statusom 'ReadyForPickup' mogu biti označene kao preuzete. Trenutni status: {reservation.Status}.");

        var now = DateTime.UtcNow;
        var previousStatus = reservation.Status;

        reservation.Status = RentalReservationStatus.PickedUp;
        reservation.PickedUpAtUtc = now;
        reservation.UpdatedAtUtc = now;

        AddStatusHistory(reservation.Id, staffUserId, previousStatus, RentalReservationStatus.PickedUp, now);

        await _context.SaveChangesAsync();

        return (await GetByIdAsync(reservation.Id, isStaff: true))!;
    }

    public async Task<RentalReservationResponse> MarkReturnedAsync(
        int id, int staffUserId, RentalReservationReturnRequest request)
    {
        var reservation = await GetReservationOrThrowAsync(id);

        if (reservation.Status != RentalReservationStatus.PickedUp)
            throw new UserException($"Samo rezervacije sa statusom 'PickedUp' mogu biti označene kao vraćene. Trenutni status: {reservation.Status}.");

        var now = DateTime.UtcNow;
        var previousStatus = reservation.Status;

        var lateFee = request.LateFeeAmount ?? 0m;
        var damageFee = request.DamageFeeAmount ?? 0m;

        if (lateFee < 0m)
            throw new UserException("LateFeeAmount ne može biti negativan.");

        if (damageFee < 0m)
            throw new UserException("DamageFeeAmount ne može biti negativan.");

        reservation.Status = RentalReservationStatus.Returned;
        reservation.ReturnedAtUtc = now;
        reservation.LateFeeAmount = lateFee;
        reservation.DamageFeeAmount = damageFee;
        reservation.TotalAmount = reservation.BaseAmount - reservation.DiscountAmount
            + reservation.DepositAmount + lateFee + damageFee;

        if (!string.IsNullOrWhiteSpace(request.Notes))
            reservation.Notes = request.Notes.Trim();

        reservation.UpdatedAtUtc = now;

        var reason = BuildReturnReason(lateFee, damageFee, request.Notes);
        AddStatusHistory(reservation.Id, staffUserId, previousStatus, RentalReservationStatus.Returned, now, reason);

        await _context.SaveChangesAsync();

        return (await GetByIdAsync(reservation.Id, isStaff: true))!;
    }

    public async Task<RentalReservationResponse> CompleteAsync(int id, int staffUserId)
    {
        var reservation = await GetReservationOrThrowAsync(id);

        if (reservation.Status != RentalReservationStatus.Returned)
            throw new UserException($"Samo vraćene rezervacije mogu biti označene kao završene. Trenutni status: {reservation.Status}.");

        var now = DateTime.UtcNow;
        var previousStatus = reservation.Status;

        reservation.Status = RentalReservationStatus.Completed;
        reservation.CompletedAtUtc = now;
        reservation.UpdatedAtUtc = now;

        AddStatusHistory(reservation.Id, staffUserId, previousStatus, RentalReservationStatus.Completed, now);

        _domainNotifications.StageCustomerNotification(
            reservation.CustomerUserId,
            "Rental rezervacija završena",
            $"Vaša rental rezervacija {reservation.ReservationNumber} je uspješno završena. Hvala na ukazanom povjerenju!",
            NotificationType.RentalCompleted,
            relatedEntityType: "RentalReservation",
            relatedEntityId: reservation.Id);

        await _context.SaveChangesAsync();

        return (await GetByIdAsync(reservation.Id, isStaff: true))!;
    }

    public async Task<List<RentalReservationStatusHistoryResponse>> GetTimelineAsync(int id)
    {
        var exists = await _context.RentalReservations
            .AnyAsync(r => r.Id == id && !r.IsDeleted);

        if (!exists)
            throw new UserException("Rezervacija nije pronađena.");

        var history = await _context.RentalReservationStatusHistories
            .Include(h => h.ChangedByUser)
            .Where(h => h.RentalReservationId == id)
            .OrderBy(h => h.ChangedAtUtc)
            .ToListAsync();

        return history.Select(h => new RentalReservationStatusHistoryResponse
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
        }).ToList();
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private IQueryable<RentalReservation> BuildBaseQuery()
    {
        return _context.RentalReservations
            .Include(r => r.Dress)
            .Include(r => r.Customer)
            .Where(r => !r.IsDeleted);
    }

    private static IQueryable<RentalReservation> ApplyFilter(
        IQueryable<RentalReservation> query, RentalReservationSearchObject search)
    {
        if (search.Status.HasValue)
            query = query.Where(r => r.Status == search.Status.Value);

        if (search.DressId.HasValue)
            query = query.Where(r => r.DressId == search.DressId.Value);

        if (search.CustomerUserId.HasValue)
            query = query.Where(r => r.CustomerUserId == search.CustomerUserId.Value);

        if (search.FromDate.HasValue)
            query = query.Where(r => r.StartDateUtc >= search.FromDate.Value);

        if (search.ToDate.HasValue)
            query = query.Where(r => r.StartDateUtc <= search.ToDate.Value);

        return query;
    }

    private async Task ValidateCreateRequestAsync(int customerId, RentalReservationCreateRequest request)
    {
        if (request.DressId <= 0)
            throw new UserException("DressId je obavezan.");

        // Verify the requesting user exists and has Customer role
        var user = await _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == customerId && !u.IsDeleted);

        if (user == null)
            throw new UserException("Korisnik nije pronađen.");

        if (user.Role != UserRole.Customer)
            throw new UserException("Samo korisnici sa ulogom Customer mogu kreirati rental rezervacije.");
    }

    private async Task ReleaseRentalHoldSlotAsync(int reservationId)
    {
        var holdSlot = await _context.DressAvailabilitySlots
            .FirstOrDefaultAsync(s => s.SourceReservationId == reservationId
                                   && s.SourceReservationType == ReservationSourceType.Rental
                                   && s.SlotType == AvailabilitySlotType.RentalHold
                                   && !s.IsDeleted);

        if (holdSlot != null)
        {
            holdSlot.IsDeleted = true;
            holdSlot.UpdatedAtUtc = DateTime.UtcNow;
        }
    }

    private async Task<RentalReservation> GetReservationOrThrowAsync(int id)
    {
        var reservation = await _context.RentalReservations
            .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

        if (reservation == null)
            throw new UserException("Rezervacija nije pronađena.");

        return reservation;
    }

    private void AddStatusHistory(
        int reservationId, int changedByUserId,
        RentalReservationStatus fromStatus, RentalReservationStatus toStatus,
        DateTime changedAtUtc, string? reason = null)
    {
        _context.RentalReservationStatusHistories.Add(new RentalReservationStatusHistory
        {
            RentalReservationId = reservationId,
            ChangedByUserId = changedByUserId,
            FromStatus = fromStatus,
            ToStatus = toStatus,
            ChangedAtUtc = changedAtUtc,
            Reason = reason
        });
    }

    private static string? BuildReturnReason(decimal lateFee, decimal damageFee, string? notes)
    {
        var parts = new List<string>();
        if (lateFee > 0m) parts.Add($"Naknada za kašnjenje: {lateFee:F2} EUR");
        if (damageFee > 0m) parts.Add($"Naknada za oštećenje: {damageFee:F2} EUR");
        if (!string.IsNullOrWhiteSpace(notes)) parts.Add(notes.Trim());
        return parts.Count > 0 ? string.Join("; ", parts) : null;
    }

    private async Task<string> GenerateUniqueReservationNumberAsync()
    {
        string number;
        bool exists;
        do
        {
            var date = DateTime.UtcNow.ToString("yyyyMMdd");
            var suffix = Guid.NewGuid().ToString("N")[..6].ToUpper();
            number = $"RENT-{date}-{suffix}";
            exists = await _context.RentalReservations.AnyAsync(r => r.ReservationNumber == number);
        } while (exists);

        return number;
    }

    private static void NormalizePagination(RentalReservationSearchObject search)
    {
        const int maxPageSize = 100;
        if (!search.PageSize.HasValue || search.PageSize.Value <= 0)
            search.PageSize = 30;
        if (search.PageSize.Value > maxPageSize)
            search.PageSize = maxPageSize;
        if (!search.Page.HasValue || search.Page.Value < 0)
            search.Page = 0;
    }

    private static DateTime NormalizeToUtc(DateTime dt)
        => dt.Kind == DateTimeKind.Utc ? dt : DateTime.SpecifyKind(dt, DateTimeKind.Utc);

    // ── Mapping ───────────────────────────────────────────────────────────────

    private static RentalReservationResponse MapToResponse(RentalReservation entity, bool includeHistory)
    {
        var response = new RentalReservationResponse
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
            StartDateUtc = entity.StartDateUtc,
            EndDateUtc = entity.EndDateUtc,
            Status = entity.Status,
            StatusLabel = entity.Status.ToString(),
            BaseAmount = entity.BaseAmount,
            DiscountAmount = entity.DiscountAmount,
            DepositAmount = entity.DepositAmount,
            LateFeeAmount = entity.LateFeeAmount,
            DamageFeeAmount = entity.DamageFeeAmount,
            TotalAmount = entity.TotalAmount,
            Currency = entity.Currency,
            Notes = entity.Notes,
            CancellationReason = entity.CancellationReason,
            CancelledAtUtc = entity.CancelledAtUtc,
            ApprovedAtUtc = entity.ApprovedAtUtc,
            PickedUpAtUtc = entity.PickedUpAtUtc,
            ReturnedAtUtc = entity.ReturnedAtUtc,
            CompletedAtUtc = entity.CompletedAtUtc,
            CreatedAtUtc = entity.CreatedAtUtc,
            UpdatedAtUtc = entity.UpdatedAtUtc
        };

        if (includeHistory && entity.StatusHistory != null)
        {
            response.StatusHistory = entity.StatusHistory
                .OrderBy(h => h.ChangedAtUtc)
                .Select(h => new RentalReservationStatusHistoryResponse
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

    private async Task TryRecordRentalReservedInteractionAsync(
        int customerUserId,
        int dressId,
        int rentalReservationId)
    {
        try
        {
            await _interactionService.RecordInteractionAsync(
                customerUserId,
                dressId,
                InteractionType.RentalReserved,
                InteractionSource.System,
                metadataJson: UserDressInteractionService.BuildReservationMetadata(
                    "rentalReservationId",
                    rentalReservationId));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                ex,
                "Neuspješan zapis RentalReserved interakcije (user {UserId}, dress {DressId}, reservation {ReservationId}).",
                customerUserId,
                dressId,
                rentalReservationId);
        }
    }
}
