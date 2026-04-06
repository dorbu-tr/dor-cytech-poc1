namespace eToro.Trading.{ServiceName}.Infrastructure.Providers.Interfaces;

/// <summary>
/// Provider for the external {ApiName} API.
/// Implementations use IHttpClientFactory + Polly for resilience.
/// </summary>
public interface I{ApiName}Provider
{
    Task<{ApiName}Response> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<List<{ApiName}Response>> GetAllAsync(CancellationToken cancellationToken = default);
}
