using Microsoft.AspNetCore.Mvc;

namespace eToro.Trading.{ServiceName}.WebApi.Dto.Requests;

/// <summary>Request for listing {Feature} items with optional filtering.</summary>
public sealed class Get{Feature}Request
{
    /// <summary>Filter by status. Null returns all.</summary>
    [FromQuery(Name = "status")]
    public string Status { get; set; }

    /// <summary>Page number (1-based).</summary>
    [FromQuery(Name = "page")]
    public int? Page { get; set; }

    /// <summary>Items per page.</summary>
    [FromQuery(Name = "pageSize")]
    public int? PageSize { get; set; }
}
