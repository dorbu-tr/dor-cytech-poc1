using eToro.Trading.Bootstrap.Models.Configurations;
using eToro.Trading.Opstool.Domain.Dto.Example;
using eToro.Trading.Opstool.Domain.Repositories;
using eToro.Trading.Opstool.Infrastructure.Configuration;
using Microsoft.Data.SqlClient;
using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;

namespace eToro.Trading.Opstool.Infrastructure.Repositories;

public sealed class DbExampleRepository : BaseRepository, IExampleRepository
{
    public DbExampleRepository(
        EtoroDatabaseConfiguration dbConfig,
        BaseRepositoryConfiguration repoConfig,
        Polly.ResiliencePipeline pipeline)
        : base(dbConfig, repoConfig, pipeline) { }

    public async Task<List<ExampleDto>> GetAllAsync()
    {
        return await ExecuteReaderAsync(
            "[dbo].[GetExample]",
            async reader =>
            {
                var results = new List<ExampleDto>();
                while (await reader.ReadAsync())
                {
                    results.Add(new ExampleDto
                    {
                        ExampleId = reader.GetInt32(reader.GetOrdinal("Id")),
                        Name = reader.GetString(reader.GetOrdinal("Name")),
                        Value = reader.GetDecimal(reader.GetOrdinal("Value")),
                        IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive"))
                    });
                }
                return results;
            });
    }

    public async Task UpdateAsync(List<ExampleDto> items, string userIdentifier)
    {
        var parameters = new List<SqlParameter>
        {
            new("@AppLoginName", SqlDbType.NVarChar, 100) { Value = userIdentifier }
        };
        await ExecuteNonQueryAsync("[dbo].[UpdateExample]", parameters, userIdentifier);
    }
}
