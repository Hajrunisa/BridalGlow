using System;
using System.Collections.Generic;

namespace BridalGlow.Model.Responses;

public class PagedResult<T>
{
    public List<T> Items { get; set; } = new();
    public int? TotalCount { get; set; }
}
