namespace eToro.Trading.{ServiceName}.WebApi.Dto.Responses;

/// <summary>Response containing a list of {Feature} items.</summary>
public sealed class Get{Feature}Response
{
    /// <summary>The list of {Feature} items.</summary>
    public List<{Feature}Item> Items { get; set; }

    /// <summary>Total count of items (for pagination).</summary>
    public int TotalCount { get; set; }
}

/// <summary>Single {Feature} item in a list response.</summary>
public sealed class {Feature}Item
{
    public int Id { get; set; }
    public string Name { get; set; }
    public string Status { get; set; }
}
