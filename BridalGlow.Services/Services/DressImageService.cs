using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace BridalGlow.Services.Services;

public class DressImageService : IDressImageService
{
    private static readonly HashSet<string> AllowedMimeTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/gif"
    };

    private static readonly Dictionary<string, string> MimeToExtension = new(StringComparer.OrdinalIgnoreCase)
    {
        { "image/jpeg", ".jpg" },
        { "image/png",  ".png" },
        { "image/webp", ".webp" },
        { "image/gif",  ".gif" }
    };

    private const long MaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

    private readonly BridalGlowDbContext _context;
    private readonly string _uploadsRoot;

    public DressImageService(BridalGlowDbContext context, IConfiguration configuration)
    {
        _context = context;
        _uploadsRoot = configuration["UPLOAD_PATH"]
            ?? Path.Combine(Directory.GetCurrentDirectory(), "uploads");
    }

    // ------------------------------------------------------------------ Read

    public async Task<List<DressImageResponse>> GetByDressIdAsync(int dressId)
    {
        var images = await _context.DressImages
            .Where(i => i.DressId == dressId && !i.IsDeleted)
            .OrderBy(i => i.SortOrder)
            .ThenBy(i => i.Id)
            .AsNoTracking()
            .ToListAsync();

        return images.Select(MapToResponse).ToList();
    }

    public async Task<DressImageResponse?> GetByIdAsync(int id)
    {
        var image = await _context.DressImages
            .AsNoTracking()
            .FirstOrDefaultAsync(i => i.Id == id && !i.IsDeleted);

        return image == null ? null : MapToResponse(image);
    }

    // ------------------------------------------------------------------ Upload

    public async Task<DressImageResponse> UploadAsync(
        int dressId,
        Stream fileStream,
        string originalFileName,
        string contentType,
        long fileSizeBytes,
        string? altText,
        bool isPrimary,
        int sortOrder)
    {
        await ValidateDressExistsAsync(dressId);

        if (fileSizeBytes > MaxFileSizeBytes)
            throw new UserException($"Veličina fajla ne smije prelaziti {MaxFileSizeBytes / 1024 / 1024} MB.");

        // 1. Validate declared MIME type
        if (!AllowedMimeTypes.Contains(contentType))
            throw new UserException("Dozvoljeni formati slika su: JPEG, PNG, WebP, GIF.");

        // 2. Validate magic bytes (actual file header)
        if (!await ValidateMagicBytesAsync(fileStream, contentType))
            throw new UserException("Sadržaj fajla ne odgovara prijavljenom tipu slike.");

        // Reset stream after magic bytes check
        fileStream.Seek(0, SeekOrigin.Begin);

        // 3. Determine extension from MIME type (never trust the original filename extension)
        var extension = MimeToExtension[contentType];
        var fileName = $"{Guid.NewGuid()}{extension}";
        var storageKey = Path.Combine("dresses", dressId.ToString(), fileName).Replace('\\', '/');
        var relativePath = $"/uploads/{storageKey}";

        // 4. Save file to disk
        var physicalDir = Path.Combine(_uploadsRoot, "dresses", dressId.ToString());
        Directory.CreateDirectory(physicalDir);

        var physicalPath = Path.Combine(physicalDir, fileName);
        await using var fs = new FileStream(physicalPath, FileMode.Create, FileAccess.Write);
        await fileStream.CopyToAsync(fs);

        // 5. Persist DB record
        if (isPrimary)
            await ClearPrimaryFlagAsync(dressId);

        var entity = new DressImage
        {
            DressId = dressId,
            Url = relativePath,
            StorageKey = storageKey,
            AltText = altText?.Trim(),
            SortOrder = sortOrder,
            IsPrimary = isPrimary,
            FileSizeBytes = fileSizeBytes,
            MimeType = contentType,
            CreatedAtUtc = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.DressImages.Add(entity);
        await _context.SaveChangesAsync();

        return MapToResponse(entity);
    }

    // ------------------------------------------------------------------ Link

    public async Task<DressImageResponse> LinkAsync(DressImageLinkRequest request)
    {
        await ValidateDressExistsAsync(request.DressId);

        if (request.IsPrimary)
            await ClearPrimaryFlagAsync(request.DressId);

        // External URL – StorageKey is empty (no local file)
        var entity = new DressImage
        {
            DressId = request.DressId,
            Url = request.Url,
            StorageKey = string.Empty,
            AltText = request.AltText?.Trim(),
            SortOrder = request.SortOrder,
            IsPrimary = request.IsPrimary,
            CreatedAtUtc = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.DressImages.Add(entity);
        await _context.SaveChangesAsync();

        return MapToResponse(entity);
    }

    // ------------------------------------------------------------------ Reorder

    public async Task<DressImageResponse?> ReorderAsync(int id, int sortOrder)
    {
        var entity = await _context.DressImages
            .FirstOrDefaultAsync(i => i.Id == id && !i.IsDeleted);

        if (entity == null)
            return null;

        entity.SortOrder = sortOrder;
        entity.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return MapToResponse(entity);
    }

    // ------------------------------------------------------------------ SetPrimary

    public async Task<DressImageResponse?> SetPrimaryAsync(int id)
    {
        var entity = await _context.DressImages
            .FirstOrDefaultAsync(i => i.Id == id && !i.IsDeleted);

        if (entity == null)
            return null;

        // Clear existing primary for this dress, then set new one – all in one SaveChanges
        await ClearPrimaryFlagAsync(entity.DressId);

        entity.IsPrimary = true;
        entity.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return MapToResponse(entity);
    }

    // ------------------------------------------------------------------ Delete

    public async Task<bool> DeleteAsync(int id)
    {
        var entity = await _context.DressImages
            .FirstOrDefaultAsync(i => i.Id == id && !i.IsDeleted);

        if (entity == null)
            return false;

        // Soft-delete the DB record (consistent with AuditableEntity pattern)
        entity.IsDeleted = true;
        entity.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    // ------------------------------------------------------------------ Mapping

    private static DressImageResponse MapToResponse(DressImage entity) => new()
    {
        Id = entity.Id,
        DressId = entity.DressId,
        Url = entity.Url,
        AltText = entity.AltText,
        SortOrder = entity.SortOrder,
        IsPrimary = entity.IsPrimary,
        MimeType = entity.MimeType,
        FileSizeBytes = entity.FileSizeBytes,
        CreatedAtUtc = entity.CreatedAtUtc
    };

    // ------------------------------------------------------------------ Private helpers

    private async Task ValidateDressExistsAsync(int dressId)
    {
        var exists = await _context.Dresses.AnyAsync(d => d.Id == dressId && !d.IsDeleted);
        if (!exists)
            throw new UserException("Vjenčanica ne postoji ili je obrisana.");
    }

    /// <summary>
    /// Clears IsPrimary on all existing non-deleted images for a dress.
    /// Changes are staged – caller must call SaveChangesAsync.
    /// </summary>
    private async Task ClearPrimaryFlagAsync(int dressId)
    {
        var currentPrimaries = await _context.DressImages
            .Where(i => i.DressId == dressId && i.IsPrimary && !i.IsDeleted)
            .ToListAsync();

        foreach (var img in currentPrimaries)
        {
            img.IsPrimary = false;
            img.UpdatedAtUtc = DateTime.UtcNow;
        }
    }

    /// <summary>
    /// Validates that the actual file bytes match the declared MIME type.
    /// Does NOT reset the stream – caller must seek back to 0.
    /// </summary>
    private static async Task<bool> ValidateMagicBytesAsync(Stream stream, string mimeType)
    {
        const int headerSize = 12;
        var buffer = new byte[headerSize];
        var read = await stream.ReadAsync(buffer, 0, headerSize);

        if (read < 3)
            return false;

        return mimeType.ToLowerInvariant() switch
        {
            "image/jpeg" =>
                buffer[0] == 0xFF && buffer[1] == 0xD8 && buffer[2] == 0xFF,

            "image/png" =>
                read >= 8 &&
                buffer[0] == 0x89 && buffer[1] == 0x50 && buffer[2] == 0x4E &&
                buffer[3] == 0x47 && buffer[4] == 0x0D && buffer[5] == 0x0A &&
                buffer[6] == 0x1A && buffer[7] == 0x0A,

            "image/gif" =>
                read >= 4 &&
                buffer[0] == 0x47 && buffer[1] == 0x49 &&
                buffer[2] == 0x46 && buffer[3] == 0x38,

            // WebP: RIFF????WEBP (bytes 0-3 = RIFF, bytes 8-11 = WEBP)
            "image/webp" =>
                read >= 12 &&
                buffer[0] == 0x52 && buffer[1] == 0x49 && buffer[2] == 0x46 && buffer[3] == 0x46 &&
                buffer[8] == 0x57 && buffer[9] == 0x45 && buffer[10] == 0x42 && buffer[11] == 0x50,

            _ => false
        };
    }
}
