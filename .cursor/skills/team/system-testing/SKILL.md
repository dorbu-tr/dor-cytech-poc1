<!-- TEAM-SPECIFIC: This file provides system testing guidance for the Trading team. Trading has limited system test infrastructure compared to other teams. -->

# Trading System Testing Patterns

## When to Use This Skill

Use when implementing: system tests, integration tests, end-to-end API tests.

## Overview

Trading services have a lighter system test footprint than other eToro teams. Most testing is done at the unit/component level via `{ServiceName}.Application.Tests`.

## System Test Structure

```
tests/
├── {ServiceName}.Application.Tests/     # Primary test project (xUnit)
│   ├── Mappers/                          # AutoMapper profile tests
│   ├── Validators/                       # FluentValidation tests
│   └── Services/                         # Service logic tests
└── {ServiceName}.Infrastructure.Tests/   # Optional infrastructure tests
    └── Repositories/                     # Repository tests (if applicable)
```

## Integration Test Pattern

For testing against real dependencies (database, external APIs):

```csharp
public class InstrumentRepositoryIntegrationTests : IAsyncLifetime
{
    private readonly string _connectionString;

    public InstrumentRepositoryIntegrationTests()
    {
        _connectionString = Environment.GetEnvironmentVariable("TEST_DB_CONNECTION")
            ?? "Server=localhost;Database=TestDb;Trusted_Connection=true;";
    }

    public Task InitializeAsync() => Task.CompletedTask;
    public Task DisposeAsync() => Task.CompletedTask;

    [Fact(Skip = "Integration test - requires database")]
    public async Task GetAll_ReturnsInstruments()
    {
        var repo = new DbInstrumentRepository(
            new EtoroDatabaseConfiguration { ConnectionString = _connectionString },
            new BaseRepositoryConfiguration { DbCommandTimeoutSeconds = 30 });

        var result = await repo.GetAllAsync();
        result.Should().NotBeNull();
    }
}
```

## Testing Stack

Same as component tests: xUnit, FluentAssertions, Moq.
