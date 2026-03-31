using eToro.Trading.Opstool.Domain.Dto.Example;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace eToro.Trading.Opstool.Domain.Repositories;

public interface IExampleRepository
{
    Task<List<ExampleDto>> GetAllAsync();
    Task UpdateAsync(List<ExampleDto> items, string userIdentifier);
}
