using System;

namespace BridalGlow.Model.Responses;

public class DressImageResponse
{
    public int Id { get; set; }
    public int DressId { get; set; }
    public string Url { get; set; } = string.Empty;
    public string? AltText { get; set; }
    public int SortOrder { get; set; }
    public bool IsPrimary { get; set; }
    public string? MimeType { get; set; }
    public long? FileSizeBytes { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
