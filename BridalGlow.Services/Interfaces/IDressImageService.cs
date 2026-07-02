using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;

namespace BridalGlow.Services.Interfaces;

public interface IDressImageService
{
    Task<List<DressImageResponse>> GetByDressIdAsync(int dressId);
    Task<DressImageResponse?> GetByIdAsync(int id);

    /// <summary>
    /// Uploads a physical file. Stream must be at position 0.
    /// MIME type and magic bytes are validated inside the service.
    /// </summary>
    Task<DressImageResponse> UploadAsync(
        int dressId,
        Stream fileStream,
        string originalFileName,
        string contentType,
        long fileSizeBytes,
        string? altText,
        bool isPrimary,
        int sortOrder);

    Task<DressImageResponse> LinkAsync(DressImageLinkRequest request);

    Task<DressImageResponse?> ReorderAsync(int id, int sortOrder);

    Task<DressImageResponse?> SetPrimaryAsync(int id);

    Task<bool> DeleteAsync(int id);
}
