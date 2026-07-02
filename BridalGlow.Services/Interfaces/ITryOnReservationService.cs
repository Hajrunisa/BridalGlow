using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface ITryOnReservationService
{
    Task<PagedResult<TryOnReservationResponse>> GetAsync(TryOnReservationSearchObject search);
    Task<TryOnReservationResponse?> GetByIdAsync(int id);
    Task<PagedResult<TryOnReservationResponse>> GetMyReservationsAsync(int customerId, TryOnReservationSearchObject search);
    Task<TryOnReservationResponse> CreateAsync(int customerId, TryOnReservationCreateRequest request);
    Task<TryOnReservationResponse> CancelAsync(int id, int userId, bool isStaff, TryOnReservationCancelRequest request);
    Task<TryOnReservationResponse> ConfirmAsync(int id, int staffUserId, TryOnReservationStatusChangeRequest request);
    Task<TryOnReservationResponse> CompleteAsync(int id, int staffUserId, TryOnReservationStatusChangeRequest request);
    Task<TryOnReservationResponse> MarkNoShowAsync(int id, int staffUserId, TryOnReservationStatusChangeRequest request);
}
