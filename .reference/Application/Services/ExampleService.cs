using eToro.Trading.Opstool.Domain.Dto.Example;
using eToro.Trading.Opstool.Domain.Repositories;
using Framework.Log;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace eToro.Trading.Opstool.Application.Services;

public sealed class ExampleService : IExampleService
{
    private readonly IExampleRepository _repository;
    private readonly ILogger _logger;

    public ExampleService(IExampleRepository repository, ILogger logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<List<ExampleDto>> GetAllAsync()
    {
        _logger.LogInfo("Retrieving all Example items");
        var result = await _repository.GetAllAsync();
        _logger.LogInfo($"Retrieved {result.Count} Example items");
        return result;
    }

    public async Task UpdateAsync(List<ExampleDto> items, string userIdentifier)
    {
        _logger.LogInfo($"Updating {items.Count} Example items by user {userIdentifier}");
        await _repository.UpdateAsync(items, userIdentifier);
        _logger.LogInfo($"Successfully updated {items.Count} Example items");
    }
}
