namespace eToro.Trading.{ServiceName}.WebApi.Extensions;

/// <summary>
/// Internalize extensions convert API-layer request DTOs into Application-layer parameters.
/// One method per endpoint request type.
/// </summary>
public static class {Feature}RequestExtensions
{
    public static Get{Feature}Parameters Internalize(this Get{Feature}Request request)
    {
        return new Get{Feature}Parameters
        {
            Status = request.Status,
            Page = request.Page ?? 1,
            PageSize = request.PageSize ?? 20
        };
    }

    public static Get{Feature}ByIdParameters Internalize(this Get{Feature}ByIdRequest request)
    {
        return new Get{Feature}ByIdParameters
        {
            Id = request.Id
        };
    }

    public static Get{Feature}SubItemsParameters Internalize(this Get{Feature}SubItemsRequest request)
    {
        return new Get{Feature}SubItemsParameters
        {
            {Feature}Id = request.{Feature}Id
        };
    }
}
