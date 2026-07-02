using System;

namespace BridalGlow.Model.Responses;

public class DressTagResponse
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
}
