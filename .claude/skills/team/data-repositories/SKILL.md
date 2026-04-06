<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/team/data-repositories/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
<!-- TEAM-SPECIFIC: This file implements data access patterns using eToro Trading NuGets — MSSQL stored procedures, BaseRepository, ADO.NET, Polly retry, Scrutor caching decorators. Teams using different libraries: replace this file with your library-specific implementations. -->

# Trading Data Repository Patterns

## When to Use This Skill

Use when implementing: MSSQL repositories, stored procedure calls, BaseRepository, retry decorators, cached repositories, Scrutor decoration, table-valued parameters, batch operations.

## Data Access Overview

Trading services use ADO.NET with SQL Server stored procedures. No Entity Framework Core or Dapper.

## BaseRepository Pattern

```csharp
public class BaseRepository
{
    private readonly string _connectionString;
    private readonly int _dbCommandTimeoutSeconds;

    public BaseRepository(string connectionString, int dbCommandTimeoutSeconds)
    {
        _connectionString = connectionString;
        _dbCommandTimeoutSeconds = dbCommandTimeoutSeconds;
    }

    protected async Task<int> ExecuteNonQueryAsync(
        string storedProcedureName, SqlParameter[] sqlParameters)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var sqlCommand = CreateSqlCommand(storedProcedureName, sqlParameters, connection);
        sqlCommand.CommandType = CommandType.StoredProcedure;
        await connection.OpenAsync();
        return await sqlCommand.ExecuteNonQueryAsync();
    }

    protected async Task<T> ExecuteReaderAsync<T>(
        string storedProcedureName, SqlParameter[] sqlParameters,
        Func<SqlDataReader, Task<T>> mapFunc)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var sqlCommand = CreateSqlCommand(storedProcedureName, sqlParameters, connection);
        sqlCommand.CommandType = CommandType.StoredProcedure;
        await connection.OpenAsync();
        await using var reader = await sqlCommand.ExecuteReaderAsync();
        return await mapFunc(reader);
    }
}
```

## Repository Implementation

```csharp
public sealed class Db{Feature}Repository : BaseRepository, I{Feature}Repository
{
    public Db{Feature}Repository(
        EtoroDatabaseConfiguration dbConfig,
        BaseRepositoryConfiguration repoConfig)
        : base(dbConfig.ConnectionString, repoConfig.DbCommandTimeoutSeconds) { }

    public async Task<List<{Feature}Dto>> GetAllAsync()
    {
        return await ExecuteReaderAsync(
            "[Schema].[StoredProcedureName]",
            null,
            async reader =>
            {
                var results = new List<{Feature}Dto>();
                while (await reader.ReadAsync())
                {
                    results.Add(new {Feature}Dto
                    {
                        Id = reader.GetInt32(reader.GetOrdinal("Id")),
                        Name = reader.GetString(reader.GetOrdinal("Name"))
                    });
                }
                return results;
            });
    }
}
```

## Cached Repository Pattern (Scrutor Decorator)

```csharp
// Bootstrap registration using Scrutor
serviceCollection.AddSingleton<I{Feature}Repository, Db{Feature}Repository>();
serviceCollection.Decorate<I{Feature}Repository, {Feature}CachedRepository>();

// Cached repository implementation
public sealed class {Feature}CachedRepository : I{Feature}Repository
{
    private readonly I{Feature}Repository _inner;
    private readonly ICache _cache;
    private readonly TimeSpan _ttl;

    public async Task<List<{Feature}Dto>> GetAllAsync()
        => await _cache.GetOrAddAsync("cache-key", () => _inner.GetAllAsync(), _ttl);
}
```

## Retry Decorator Pattern

```csharp
public sealed class {Feature}RepositoryRetryDecorator : I{Feature}Repository
{
    private readonly I{Feature}Repository _inner;
    private readonly ResiliencePipeline _retryPipeline;

    public async Task<List<{Feature}Dto>> GetAllAsync()
        => await _retryPipeline.ExecuteAsync(async ct => await _inner.GetAllAsync());
}
```

## Connection String Configuration

Connection strings come from KeyVault, NOT appsettings:
- `MainDbConnectionString` — primary database
- `ReplicaDbConnectionString` — read replica (optional)

## Required NuGet Packages

```xml
<PackageReference Include="eToro.Trading.Sql.DbAccess" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Sql.ErrorsDetection" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Sql.Persistors" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.RetryHandling" Version="$(TradingCoreBuildVersion)" />
```

## Full Database Reference

Read [references/database-access.md](references/database-access.md) for:
- Complete BaseRepository implementation
- Retry decorator pattern details
- DbSelector for read replicas
- Connection string configuration per environment
