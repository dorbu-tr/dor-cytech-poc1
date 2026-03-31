using AutoMapper;

namespace eToro.Trading.{ServiceName}.WebApi.Extensions;

/// <summary>
/// Externalize extensions convert Application-layer results into API-layer response DTOs.
/// One method per endpoint result type.
/// </summary>
public static class {Feature}ResponseExtensions
{
    public static Get{Feature}Response Externalize(
        this Get{Feature}Result result, IMapper mapper)
    {
        return new Get{Feature}Response
        {
            Items = mapper.Map<List<{Feature}Item>>(result.Items),
            TotalCount = result.TotalCount
        };
    }

    public static Get{Feature}ByIdResponse Externalize(
        this Get{Feature}ByIdResult result, IMapper mapper)
    {
        return new Get{Feature}ByIdResponse
        {
            Item = mapper.Map<{Feature}Item>(result.Entity)
        };
    }

    public static Get{Feature}SubItemsResponse Externalize(
        this Get{Feature}SubItemsResult result, IMapper mapper)
    {
        return new Get{Feature}SubItemsResponse
        {
            Items = mapper.Map<List<SubItem>>(result.SubItems)
        };
    }
}
