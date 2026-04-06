# Database Access Patterns

## Overview

Trading services use ADO.NET with SQL Server stored procedures. No EF Core or Dapper.

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

    private SqlCommand CreateSqlCommand(
        string storedProcedureName, SqlParameter[] sqlParameters, SqlConnection connection)
    {
        var cmd = new SqlCommand(storedProcedureName, connection)
        {
            CommandTimeout = _dbCommandTimeoutSeconds
        };
        if (sqlParameters != null)
            cmd.Parameters.AddRange(sqlParameters);
        return cmd;
    }
}
```

## Repository Implementation

```csharp
public sealed class {Feature}Repository : BaseRepository, I{Feature}Repository
{
    public {Feature}Repository(
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

## Retry Decorator Pattern

Wrap repositories with Polly retry:

```csharp
public sealed class {Feature}RepositoryRetryDecorator : I{Feature}Repository
{
    private readonly I{Feature}Repository _inner;
    private readonly IAsyncPolicy _retryPolicy;

    public {Feature}RepositoryRetryDecorator(
        I{Feature}Repository inner, IAsyncPolicy retryPolicy)
    {
        _inner = inner;
        _retryPolicy = retryPolicy;
    }

    public async Task<List<{Feature}Dto>> GetAllAsync()
        => await _retryPolicy.ExecuteAsync(() => _inner.GetAllAsync());
}
```

Bootstrap registration:
```csharp
serviceCollection.AddSingleton<I{Feature}Repository>(sp =>
{
    var repo = new {Feature}Repository(
        sp.GetRequiredService<EtoroDatabaseConfiguration>(),
        sp.GetRequiredService<BaseRepositoryConfiguration>());

    return new {Feature}RepositoryRetryDecorator(
        repo, sp.GetRequiredService<IAsyncPolicy>());
});
```

## Connection String Configuration

Connection strings come from KeyVault, NOT appsettings:
- `MainDbConnectionString` -- primary database
- `ReplicaDbConnectionString` -- read replica (optional)

KeyVault secret names per environment:
- QA: `QA{N}-MainDbConnectionString`
- Staging/Prod: `MainDbConnectionString`

## DbSelector (Optional)

For read replicas and geo-aware database selection:

```csharp
serviceCollection
    .RegisterAutoUpdatedConfiguration<{ServiceName}Configuration>("{ServiceName}")
    .WithSubConfiguration(c => c.EtoroDatabase)
    .WithSubConfiguration(c => c.DbSelectorConfiguration)
    .WithEnrichedSubConfiguration(c => c.EtoroDatabase,
        new DbSelectorConfigurationEnricherWithDependency());
```

**Decision Guide:**

| Scenario | Use DbSelector? |
|----------|-----------------|
| Single database instance | No |
| Read-only queries to replicas | Yes |
| Multi-region with local DBs | Yes |
| Low-latency requirements | Yes (respects delay limits) |
| Simple CRUD operations | No (unnecessary overhead) |

## Required NuGet Packages

```xml
<PackageReference Include="eToro.Trading.Sql.DbAccess" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Sql.ErrorsDetection" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.Sql.Persistors" Version="$(TradingCoreBuildVersion)" />
<PackageReference Include="eToro.Trading.RetryHandling" Version="$(TradingCoreBuildVersion)" />
```
