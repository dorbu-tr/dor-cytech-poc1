# Implementation Pitfalls

## Pre-Implementation Mandatory Checklist

BEFORE writing ANY code, verify:

```
- SDK Version: [Checked/N/A]
- Logger Type: [Checked/N/A]
- Template Cleanup: [Checked/N/A]
- ISCBFacade Package: [Checked/N/A]
- KeyVault Defaults: [Checked/N/A]
- Gate tasks in tasks.md: [Yes/Missing]
```

---

## SDK Version Alignment

Template `global.json` may specify an SDK not installed on your machine.

```bash
dotnet --list-sdks      # Check installed
cat global.json         # Check required
```

Fix: Update `global.json` to match an installed SDK.

---

## Logger Type Resolution

Ambiguity between `Framework.Log.ILogger` (eToro) and `Microsoft.Extensions.Logging.ILogger<T>` (Microsoft).

**Rule**: In service/repository/controller files, ONLY import `Framework.Log`:

```csharp
// CORRECT - service files
using Framework.Log;
private readonly ILogger _logger;

// CORRECT - Program.cs only (needs both)
using Framework.Log;
using Microsoft.Extensions.Logging;
builder.Host.ConfigureLogging((ctx, cfg) => cfg.AddLog4Net());

// WRONG - causes ambiguity
using Framework.Log;
using Microsoft.Extensions.Logging;
private readonly ILogger<MyService> _logger;  // Wrong generic form
```

Logger methods: `LogInfo()`, `LogError()`, `LogWarn()`, `LogDebug()`.

---

## Template Conditional Compilation Cleanup

Templates use `#if` directives. Remove unused blocks:

| Feature Flag | When to REMOVE |
|--------------|----------------|
| `#if(include-rabbit)` | No RabbitMQ needed |
| `#if(include-redis)` | No Redis caching |
| `#if(include-worker-service)` | No background workers |
| `#if(include-app-secret-auth)` | No AppSecret auth |
| `#if(include-db)` | No database access |

---

## Layer Dependencies & Circular References

Valid one-way chain:
```
WebApi -> Bootstrap -> Application -> Infrastructure -> Domain
```

Common mistake: Adding Bootstrap reference to Infrastructure creates cycle. Solution: Move config classes to `Domain/Data/`.

### Required Project References

| Project | Must Reference |
|---------|---------------|
| Application | Domain |
| Infrastructure | Domain, Application |
| Bootstrap | Domain, Application, Infrastructure |
| WebApi | Bootstrap |
| Tests | Corresponding source + Domain |

---

## ISCBFacade / CommunicationLayer Package

`ISCBFacade` is in namespace `CommunicationLayer` from package `eToro.Trading.CommunicationLayer`, NOT in the SCB package.

```xml
<PackageReference Include="eToro.Trading.CommunicationLayer" Version="$(FrameworkBuildVersion)" />
```

```csharp
using CommunicationLayer;  // NOT eToro.Trading.Configuration.Providers.Scb.Abstractions
services.AddSingletonFromContext<ISCBFacade>(hostBuilderContext);
```

---

## KeyVault Configuration Property Defaults

Properties MUST have meaningful defaults (actual secret names):

```csharp
// CORRECT
public string EtoroDbConnectionString { get; set; } = "eToroDbConnectionString";
public string PasAppSecret { get; set; } = "PasAppSecret";

// WRONG - causes empty secret name lookups -> crash
public string EtoroDbConnectionString { get; set; } = string.Empty;
```

The KeyVault provider uses property values as secret names. `string.Empty` -> tries `/secrets/` with no name -> crash.

---

## Health Check Anti-Patterns

**Anti-Pattern 1 — missing `AddHealthChecks()` (runtime exception):**
```csharp
// WRONG: ConfigureHealthChecks without AddHealthChecks() first in Program.cs
// Throws: InvalidOperationException: Unable to find the required services.
// Please add all the required services by calling 'IServiceCollection.AddHealthChecks'
services.ConfigureHealthChecks(GetHealthCheckCacheResultInSeconds);  // FAILS
```
Fix: `services.AddHealthChecks()` MUST be called in `Program.cs` BEFORE `.ConfigureHealthChecks()`.

**Anti-Pattern 2 — ConnectionString from appsettings instead of KeyVault (runtime exception):**
```csharp
// WRONG: Using IConfiguration.GetConnectionString() for database connection
// Connection strings come from KeyVault, not appsettings.json ConnectionStrings section
// Throws: HealthCheckException: The ConnectionString property has not been initialized
services.ConfigureHealthChecks(GetHealthCheckCacheResultInSeconds,
    new HealthCheckDatabaseCommandBuilder("etoroDb",
        sp => configuration.GetConnectionString("EtoroDb")));  // FAILS
```
Fix: Use `sp => sp.GetRequiredService<EtoroDatabaseConfiguration>().ConnectionString` — the connection string is populated from KeyVault via `[KeyVaultConfigurationOverride]`.

---

## Test Mock Configuration

When adding dependencies, update test `SetUp()`:

```csharp
[SetUp]
public void SetUp()
{
    _repositoryMock = new Mock<IMyRepository>();
    _repositoryMock.Setup(x => x.GetDataAsync()).ReturnsAsync(expectedData);
    _service = new MyService(_repositoryMock.Object);
}
```

---

## ASP.NET Core Environment Checks

```csharp
// CORRECT
if (app.Environment.IsDevelopment()) { }
if (!app.Environment.IsProduction()) { }

// WRONG
if (app.Environment.EnvironmentName.ToLower().StartsWith("prod")) { }
```
