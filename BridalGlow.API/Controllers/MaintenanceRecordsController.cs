using System;
using BridalGlow.API.Filters;
using BridalGlow.Model.Constants;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/MaintenanceRecords")]
[Authorize(Roles = RoleNames.AdminOrStaff)]
public class MaintenanceRecordsController : ControllerBase
{
    private readonly IMaintenanceRecordService _service;

    public MaintenanceRecordsController(IMaintenanceRecordService service)
    {
        _service = service;
    }

    // ── Read ──────────────────────────────────────────────────────────────────

    /// <summary>
    /// Returns a paged list of maintenance records with optional filters
    /// (dressId, status, maintenanceType, recordedByUserId, fromDate, toDate).
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<PagedResult<MaintenanceRecordResponse>>> GetAll(
        [FromQuery] MaintenanceRecordSearchObject? search = null)
    {
        return await _service.GetAsync(search ?? new MaintenanceRecordSearchObject());
    }

    /// <summary>
    /// Returns a single maintenance record by ID.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<MaintenanceRecordResponse>> GetById(int id)
    {
        var record = await _service.GetByIdAsync(id);
        if (record == null)
            return NotFound();

        return record;
    }

    /// <summary>
    /// Returns a cost and record-count summary for a specific dress.
    /// Results can be narrowed by fromDate and toDate (matched against PerformedAtUtc).
    /// </summary>
    [HttpGet("summary")]
    public async Task<ActionResult<MaintenanceSummaryResponse>> GetSummary(
        [FromQuery] int dressId,
        [FromQuery] DateTime? fromDate = null,
        [FromQuery] DateTime? toDate = null)
    {
        if (dressId <= 0)
            return BadRequest(new { errors = new { dressId = new[] { "dressId je obavezan parametar." } } });

        return await _service.GetSummaryAsync(dressId, fromDate, toDate);
    }

    // ── Create ────────────────────────────────────────────────────────────────

    /// <summary>
    /// Creates a new maintenance record for a dress. Initial status is Logged.
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<MaintenanceRecordResponse>> Create(
        [FromBody] MaintenanceRecordCreateRequest request)
    {
        var staffUserId = User.GetUserId();
        var created = await _service.CreateAsync(staffUserId, request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    // ── Update ────────────────────────────────────────────────────────────────

    /// <summary>
    /// Updates descriptive fields on a Logged or InProgress maintenance record.
    /// Status changes must use the dedicated transition endpoints.
    /// </summary>
    [HttpPut("{id:int}")]
    public async Task<ActionResult<MaintenanceRecordResponse>> Update(
        int id, [FromBody] MaintenanceRecordUpdateRequest request)
    {
        return await _service.UpdateAsync(id, request);
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    /// <summary>
    /// Soft-deletes a maintenance record. Records in InProgress status must be cancelled first.
    /// </summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _service.DeleteAsync(id);
        if (!deleted)
            return NotFound();

        return NoContent();
    }

    // ── Manual dress condition ────────────────────────────────────────────────

    /// <summary>
    /// Manually sets the condition of a dress (Excellent, VeryGood, Good, NeedsRepair).
    /// Useful after ad-hoc inspection or repair outside a formal maintenance record.
    /// </summary>
    [HttpPut("dresses/{dressId:int}/condition")]
    public async Task<IActionResult> UpdateDressCondition(
        int dressId, [FromBody] UpdateDressConditionRequest request)
    {
        await _service.UpdateDressConditionAsync(dressId, request.Condition);
        return NoContent();
    }

    // ── Status transitions ────────────────────────────────────────────────────

    /// <summary>
    /// Starts maintenance work: Logged → InProgress.
    /// </summary>
    [HttpPost("{id:int}/start")]
    public async Task<ActionResult<MaintenanceRecordResponse>> Start(int id)
    {
        return await _service.StartAsync(id);
    }

    /// <summary>
    /// Marks maintenance as completed: InProgress → Completed.
    /// </summary>
    [HttpPost("{id:int}/complete")]
    public async Task<ActionResult<MaintenanceRecordResponse>> Complete(int id)
    {
        return await _service.CompleteAsync(id);
    }

    /// <summary>
    /// Cancels a Logged or InProgress maintenance record.
    /// </summary>
    [HttpPost("{id:int}/cancel")]
    public async Task<ActionResult<MaintenanceRecordResponse>> Cancel(int id)
    {
        return await _service.CancelAsync(id);
    }
}
