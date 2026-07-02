using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IDressAvailabilitySlotService
{
    Task<PagedResult<DressAvailabilitySlotResponse>> GetAsync(DressAvailabilitySlotSearchObject search);
    Task<DressAvailabilitySlotResponse?> GetByIdAsync(int id);
    Task<DressAvailabilitySlotResponse> CreateAsync(DressAvailabilitySlotCreateRequest request);
    Task<bool> DeleteAsync(int id);
    Task<List<DressAvailabilitySlotResponse>> GetFreeSlotsAsync(int dressId, DateTime date);

    /// <summary>
    /// Returns all availability slots (Available + blocking) for a dress within the next year.
    /// Used by customers to determine bookable rental periods.
    /// </summary>
    Task<List<DressAvailabilitySlotResponse>> GetRentalAvailabilityAsync(int dressId);

    /// <summary>
    /// Validates that a rental period is bookable: every calendar day in the
    /// rental window must fall within an Available slot and the window must not
    /// overlap any Block, TryOnHold, RentalHold or MaintenanceBlock slot.
    /// </summary>
    Task ValidateRentalPeriodAsync(int dressId, DateTime startUtc, DateTime endUtc);
}
