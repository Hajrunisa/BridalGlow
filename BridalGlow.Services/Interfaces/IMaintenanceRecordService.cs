using System;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;

namespace BridalGlow.Services.Interfaces;

public interface IMaintenanceRecordService
{
    Task<PagedResult<MaintenanceRecordResponse>> GetAsync(MaintenanceRecordSearchObject search);
    Task<MaintenanceRecordResponse?> GetByIdAsync(int id);

    Task<MaintenanceRecordResponse> CreateAsync(int staffUserId, MaintenanceRecordCreateRequest request);
    Task<MaintenanceRecordResponse> UpdateAsync(int id, MaintenanceRecordUpdateRequest request);
    Task<bool> DeleteAsync(int id);

    // ── Status transitions ────────────────────────────────────────────────────
    Task<MaintenanceRecordResponse> StartAsync(int id);
    Task<MaintenanceRecordResponse> CompleteAsync(int id);
    Task<MaintenanceRecordResponse> CancelAsync(int id);

    // ── Summary ───────────────────────────────────────────────────────────────
    Task<MaintenanceSummaryResponse> GetSummaryAsync(int dressId, DateTime? fromDate, DateTime? toDate);

    // ── Manual dress condition update ─────────────────────────────────────────
    Task UpdateDressConditionAsync(int dressId, DressCondition condition);
}
