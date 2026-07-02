using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IRentalReservationService
{
    Task<PagedResult<RentalReservationResponse>> GetAsync(RentalReservationSearchObject search);
    Task<RentalReservationResponse?> GetByIdAsync(int id, int? requestingUserId = null, bool isStaff = false);
    Task<PagedResult<RentalReservationResponse>> GetMineAsync(int customerId, RentalReservationSearchObject search);
    Task<RentalReservationResponse> CreateAsync(int customerId, RentalReservationCreateRequest request);
    Task<RentalReservationResponse> CancelAsync(int id, int userId, bool isStaff, RentalReservationCancelRequest request);

    // ── Staff lifecycle ───────────────────────────────────────────────────────
    Task<RentalReservationResponse> ApproveAsync(int id, int staffUserId);
    Task<RentalReservationResponse> RejectAsync(int id, int staffUserId, RentalReservationStatusChangeRequest request);
    Task<RentalReservationResponse> MarkReadyForPickupAsync(int id, int staffUserId);
    Task<RentalReservationResponse> MarkPickedUpAsync(int id, int staffUserId);
    Task<RentalReservationResponse> MarkReturnedAsync(int id, int staffUserId, RentalReservationReturnRequest request);
    Task<RentalReservationResponse> CompleteAsync(int id, int staffUserId);
    Task<List<RentalReservationStatusHistoryResponse>> GetTimelineAsync(int id);
}
