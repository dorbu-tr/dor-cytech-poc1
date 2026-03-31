using eToro.Trading.Opstool.Domain.Dto.Example;
using eToro.Trading.Opstool.Domain.Repositories;
using eToro.Trading.Opstool.Infrastructure.Configuration;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace eToro.Trading.Opstool.Infrastructure.Repositories;

/// <summary>
/// Cached decorator for IExampleRepository.
/// Registered via Scrutor: services.Decorate&lt;IExampleRepository, ExampleCachedRepository&gt;()
/// </summary>
public sealed class ExampleCachedRepository : IExampleRepository
{
    private readonly IExampleRepository _inner;
    private readonly ICache _cache;
    private readonly string _cacheKey;
    private readonly TimeSpan _ttl;

    public ExampleCachedRepository(
        IExampleRepository inner,
        ICache cache,
        ExampleCachedRepositoryConfiguration config)
    {
        _inner = inner;
        _cache = cache;
        _cacheKey = config.Example_CACHE_KEY;
        _ttl = config.ExampleRepositoryCacheTtl;
    }

    public async Task<List<ExampleDto>> GetAllAsync()
        => await _cache.GetOrAddAsync(_cacheKey, () => _inner.GetAllAsync(), _ttl);

    public async Task UpdateAsync(List<ExampleDto> items, string userIdentifier)
    {
        await _inner.UpdateAsync(items, userIdentifier);
        await _cache.RemoveAsync(_cacheKey);
    }
}
