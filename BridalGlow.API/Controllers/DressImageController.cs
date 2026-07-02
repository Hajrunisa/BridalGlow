using BridalGlow.API.Models;
using BridalGlow.Model.Constants;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/dress-images")]
[Authorize]
public class DressImageController : ControllerBase
{
    private readonly IDressImageService _dressImageService;

    public DressImageController(IDressImageService dressImageService)
    {
        _dressImageService = dressImageService;
    }

    /// <summary>
    /// Returns all images for a given dress, ordered by SortOrder.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<DressImageResponse>>> GetByDress([FromQuery] int dressId)
    {
        if (dressId <= 0)
            return BadRequest("Parametar dressId je obavezan.");

        return await _dressImageService.GetByDressIdAsync(dressId);
    }

    /// <summary>
    /// Returns a single image by its ID.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<DressImageResponse>> GetById(int id)
    {
        var image = await _dressImageService.GetByIdAsync(id);
        if (image == null)
            return NotFound();

        return image;
    }

    /// <summary>
    /// Uploads an image file (multipart/form-data).
    /// Validates MIME type and magic bytes.
    /// </summary>
    [HttpPost("upload")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<ActionResult<DressImageResponse>> Upload([FromForm] DressImageUploadFormRequest request)
    {
        if (request.File == null || request.File.Length == 0)
            return BadRequest("Fajl je obavezan.");

        await using var stream = request.File.OpenReadStream();

        var result = await _dressImageService.UploadAsync(
            dressId: request.DressId,
            fileStream: stream,
            originalFileName: request.File.FileName,
            contentType: request.File.ContentType,
            fileSizeBytes: request.File.Length,
            altText: request.AltText,
            isPrimary: request.IsPrimary,
            sortOrder: request.SortOrder);

        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    /// <summary>
    /// Links an external URL-based image (no physical file upload).
    /// Used for seed data and manual URL additions.
    /// </summary>
    [HttpPost("link")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressImageResponse>> Link([FromBody] DressImageLinkRequest request)
    {
        var result = await _dressImageService.LinkAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    /// <summary>
    /// Updates the SortOrder of an image.
    /// </summary>
    [HttpPut("{id:int}/reorder")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressImageResponse>> Reorder(int id, [FromBody] DressImageReorderRequest request)
    {
        var result = await _dressImageService.ReorderAsync(id, request.SortOrder);
        if (result == null)
            return NotFound();

        return result;
    }

    /// <summary>
    /// Sets this image as the primary image for its dress.
    /// Automatically clears IsPrimary on all other images of the same dress.
    /// </summary>
    [HttpPut("{id:int}/set-primary")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<ActionResult<DressImageResponse>> SetPrimary(int id)
    {
        var result = await _dressImageService.SetPrimaryAsync(id);
        if (result == null)
            return NotFound();

        return result;
    }

    /// <summary>
    /// Soft-deletes an image record.
    /// </summary>
    [HttpDelete("{id:int}")]
    [Authorize(Roles = RoleNames.AdminOrStaff)]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _dressImageService.DeleteAsync(id);
        if (!deleted)
            return NotFound();

        return NoContent();
    }
}
