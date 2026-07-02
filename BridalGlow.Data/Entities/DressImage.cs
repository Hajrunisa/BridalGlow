namespace BridalGlow.Data.Entities;

public class DressImage : AuditableEntity
{
    public int DressId { get; set; }
    public string Url { get; set; } = string.Empty;
    public string StorageKey { get; set; } = string.Empty;
    public string? AltText { get; set; }
    public int SortOrder { get; set; }
    public bool IsPrimary { get; set; }
    public int? WidthPx { get; set; }
    public int? HeightPx { get; set; }
    public long? FileSizeBytes { get; set; }
    public string? MimeType { get; set; }

    public Dress Dress { get; set; } = null!;
}
