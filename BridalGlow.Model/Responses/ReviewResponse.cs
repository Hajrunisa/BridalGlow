using System;
using BridalGlow.Model.Enums;

namespace BridalGlow.Model.Responses;

public class ReviewResponse
{
    public int Id { get; set; }

    public int DressId { get; set; }
    public string DressName { get; set; } = string.Empty;
    public string DressCode { get; set; } = string.Empty;

    public int CustomerUserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;

    public int? RentalReservationId { get; set; }

    public int Rating { get; set; }
    public string? Title { get; set; }
    public string? Comment { get; set; }

    public ReviewStatus Status { get; set; }
    public string StatusLabel { get; set; } = string.Empty;

    public string? ModerationNote { get; set; }
    public string? StaffReply { get; set; }

    public DateTime? PublishedAtUtc { get; set; }
    public DateTime? HiddenAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}
