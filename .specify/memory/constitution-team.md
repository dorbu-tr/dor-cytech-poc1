# Service Constitution — Team-Specific (eToro Trading NuGets)
<!-- TEAM-SPECIFIC: This file extends constitution.md with eToro Trading NuGet-specific rules. Teams using different libraries: replace this file with your library-specific rules while keeping constitution.md intact. -->
<!-- Version: 2.0.0 | Derived from: trading-templates constitution v3.2.1 + trading-standards repo + GitHub source audit -->

## Multi-Agent Architecture — Specific Files

**Subagents** (own isolated context window, split into core/ + team/):
- `core/infra-developer.md` + `team/infra-developer.md` — Infrastructure layer
- `core/app-developer.md` + `team/app-developer.md` — Application layer
- `core/api-developer.md` + `team/api-developer.md` — API layer
- `core/test-developer.md` + `team/test-developer.md` — Component + System tests

**Team Skills** (detailed HOW patterns with eToro Trading NuGets):
- `team/config-ccm` — CCM, KeyVault, SCB configuration providers, `RegisterAutoUpdatedConfiguration`
- `team/rest-provider` — External API providers, `IHttpClientFactory` + Polly resilience (NOT Framework.FaultTolerance for HTTP)
- `team/data-repositories` — MSSQL stored procedures, `BaseRepository`, cached repositories, Scrutor
- `team/component-testing` — xUnit, FluentAssertions, Moq test patterns
- `team/system-testing` — System test patterns
- `team/api-controllers` — Controller patterns, AppSecret/STS auth, FluentValidation, AutoMapper
- `team/monitoring-logging` — Framework.Log, ILogger, LoggerWrapper, structured logging
- `team/worker-service` — Background workers, RabbitMQ, event routing (Trading-specific)
- `team/orchestration` — Saga orchestration, leader election, multi-instance (Trading-specific)

---

## Session Initialization (AI MUST READ FIRST)

### MCP Auto-Installation (REQUIRED AT SESSION START)

At session start, test the `api-discovery` MCP and auto-install if missing:

**Step 1: Test MCP**
- Test `api-discovery`: call `etoro-get-all-repositories` → AVAILABLE or UNAVAILABLE

**Step 2: If available** → proceed silently.

**Step 3: If UNAVAILABLE:**
1. Locate the MCP configuration file for your IDE:
   - **Cursor**: `~/.cursor/mcp.json`
   - **Claude Code**: `~/.claude/mcp.json` or project `.mcp.json`
   - **Other IDEs**: Check IDE documentation for MCP server configuration
2. Create the config file with `{"mcpServers": {}}` if missing
3. Add missing entry:
   - `api-discovery` missing → add: `{"type": "http", "url": "http://int-etoro-services-mcp.dev.local/"}`
4. Write back (preserve all existing entries)
5. Inform user which MCPs were configured and to restart their IDE
6. If entry exists but tools still unavailable → VPN or restart needed

**Note**: Trading does NOT use the `infra-nugets` MCP (that serves eToro.Infrastructure.* documentation). Trading uses its own NuGet packages from three GitHub repositories — see `nugetRepos` in `team.json` for source URLs. When investigating what types/interfaces exist in a Trading NuGet, clone the source repo and search directly rather than guessing.

---

## Official Standards Repository

The [trading-standards](https://github.com/eToro/trading-standards) repo is the **central source of truth** for the Trading team's constitution (v3.2.1), AI agent skills, and development workflows. Install via:
```bash
npx github:etoro/trading-standards setup
```
This installs IDE-specific rules, skills, and the constitution directly into any Trading .NET service project.

---

## Example Projects — Best Practice References (NON-NEGOTIABLE)

The following production repos are the **canonical examples** of how the Trading team builds services. When in doubt about a pattern, convention, or approach — look at how these repos do it:

| Repository | Purpose | Best Examples Of |
|------------|---------|------------------|
| [trading-orders-api](https://github.com/eToro/trading-orders-api) | Order lifecycle (Modern Dual-API) | **IBootstrap/BaseBootstrap** pattern, Dual WebApi (Customer + Admin), STS auth + AppSecret, C# 12, nullable, ConfigureHost local function, RampUp |
| [trading-copy-api](https://github.com/eToro/trading-copy-api) | Mirror operations (Modern Dual-API) | Same architecture as trading-orders-api — use as second reference for dual-API pattern |
| [trading-opstool-api](https://github.com/eToro/trading-opstool-api) | Ops tool (Single-API, Database) | Static bootstrapper pattern, MSSQL stored procedures, AppSecret auth, BaseRepository, Polly v8, cached repositories via Scrutor |
| [trading-data-api](https://github.com/eToro/trading-data-api) | Trading data (Aggregator) | IHttpClientFactory + typed clients, factory-method provider registration, Polly retry/circuit breaker |
| [trading-settings-api](https://github.com/eToro/trading-settings-api) | Settings (Single-API, Hybrid) | Factory-method providers, Cosmos + SQL, Scrutor decorator caching, RabbitMQ publishers |

### Service Architecture Decision

| If your service... | Follow | Pattern |
|---|---|---|
| Has customer-facing + admin endpoints | trading-orders-api | Dual-API with IBootstrap/BaseBootstrap |
| Is a single backend service with DB | trading-opstool-api | Single-API with static bootstrappers |
| Calls only external APIs (no DB) | trading-data-api | Aggregator with IHttpClientFactory + Polly |
| Has mixed data sources (SQL + Cosmos + APIs) | trading-settings-api | Factory-method providers with Scrutor |

**How agents MUST use example projects**:
1. **Pattern discovery** — before implementing a new pattern, check if an example project already implements it. If it does, follow that approach exactly.
2. **Convention alignment** — naming conventions, folder structure, DI registration patterns, error handling — all MUST match the example projects.
3. **Conflict resolution** — if a skill describes a pattern differently than the example project, the example project wins (it's production-tested code).
4. **New patterns** — for patterns not covered by skills or `.reference/`, clone and study the example project code.

---

## Trading Service Architecture (NON-NEGOTIABLE)

### Project Structure

Trading services use a **5-layer architecture** with a dedicated Bootstrap project. Two patterns exist:

**Single-API** (trading-opstool-api, trading-settings-api):
```
{ServiceName}.sln
├── src/
│   ├── {ServiceName}.Domain/           # DTOs, Entities, Validators, Repository interfaces
│   ├── {ServiceName}.Infrastructure/   # Repository implementations, External API providers
│   ├── {ServiceName}.Application/      # Services, Mappers, Authorization
│   ├── {ServiceName}.Bootstrap/        # DI registration, Config, Health checks
│   └── {ServiceName}.WebApi/           # Controllers, Middlewares, Program.cs
├── tests/
│   ├── {ServiceName}.Application.Tests/
│   └── {ServiceName}.Infrastructure.Tests/
├── charts/{service-name}/
├── shared.props
└── {ServiceName}.sln
```

**Dual-API** (trading-orders-api, trading-copy-api) — for services with customer-facing + admin endpoints:
```
{ServiceName}.sln
├── src/
│   ├── customer/
│   │   ├── {ServiceName}.WebApi/           # Customer controllers
│   │   ├── {ServiceName}.BootStrap/        # Customer DI (extends BaseBootstrap)
│   │   └── {ServiceName}.DTO/              # Customer DTOs
│   ├── admin/
│   │   ├── {ServiceName}.Admin.WebApi/     # Admin controllers
│   │   ├── {ServiceName}.Admin.BootStrap/  # Admin DI (extends BaseBootstrap)
│   │   └── {ServiceName}.Admin.DTO/        # Admin DTOs
│   ├── {ServiceName}.Bootstrap.Core/       # IBootstrap, BaseBootstrap, shared bootstrap
│   ├── {ServiceName}.Application/
│   ├── {ServiceName}.Application.DTO/
│   ├── {ServiceName}.Domain/
│   └── {ServiceName}.Infrastructure/
├── tests/
├── charts/
├── shared.props
└── {ServiceName}.sln
```

**Layer Dependencies** (one-way only):
```
WebApi → Bootstrap → Application → Infrastructure → Domain
```

**NOTE**: The unified template merges Bootstrap into the Api project for compatibility with the 4-layer template structure. When scaffolding a real Trading service, use `templates/eToro-Service/` from the [trading-templates](https://github.com/eToro/trading-templates) repo to get the proper 5-layer structure with `dotnet new etoroservice`.

### Service Architecture Types

| Type | Description |
|------|-------------|
| Database Service | Connects to eToro database |
| Aggregator Service | Calls other APIs only |
| Hybrid Service | Database + external APIs |
| Orchestration Service | Long-running multi-step operations with saga state |

---

## NuGet Version Policy (NON-NEGOTIABLE)

### shared.props Version Variables

Every Trading service MUST have a `shared.props` at the repo root with version variables. For Trading packages, ALWAYS use `$(VersionVariable)` references in `.csproj` — NOT hardcoded versions. For external packages (FluentValidation, AutoMapper, Polly), standard NuGet.org versions are acceptable.

```xml
<Project>
  <PropertyGroup>
    <TradingCoreBuildVersion>1.17.0-rc0154-dev18</TradingCoreBuildVersion>
    <TradingSharedBuildVersion>160.12.0-beta.116</TradingSharedBuildVersion>
    <FrameworkBuildVersion>1864.2.2-TRADEA-1972-Fix-References.75</FrameworkBuildVersion>
    <LangVersion>12.0</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <AssemblyName>eToro.Trading.$(MSBuildProjectName)</AssemblyName>
    <RootNamespace>eToro.Trading.$(MSBuildProjectName.Replace(" ", "_"))</RootNamespace>
  </PropertyGroup>
</Project>
```

> **Version discovery**: The versions above are known-good combinations from production services (trading-orders-api, trading-copy-api). For newer versions, check the eToro NuGet feed or the latest `shared.props` in the example repos.

| Repository | Variable | Packages |
|------------|----------|----------|
| **trading-core** | `$(TradingCoreBuildVersion)` | Bootstrap.Models, Bootstrap.HealthCheck, Configuration.Providers.Ccm/KeyVault/Scb, Sql.DbAccess, RetryHandling, Communication.* |
| **trading-shared** | `$(TradingSharedBuildVersion)` | Domain.Entities, Domain.Repositories, Application.Messages, Infrastructure.Providers, Infrastructure.Repositories |
| **trading-framework** | `$(FrameworkBuildVersion)` | Framework.Log, Framework.Metrics, Framework.RedisClient, Framework.RabbitMQ, Framework.FaultTolerance (SQL retry only), Application.HealthCheck.Extensions |

### Forbidden Replacements (NON-NEGOTIABLE)

| FORBIDDEN (vanilla / Microsoft) | USE INSTEAD (Trading Core / Shared / Framework) |
|--------------------------------|------------------------------------------------|
| `Microsoft.Extensions.Logging.ILogger<T>` | `Framework.Log.ILogger<T>` + `LoggerWrapper` + `log4net`. Register via `AddFrameworkLogger(new LoggerWrapper())` + `RegisterGenericFrameworkLoggers()` from `eToro.Trading.Bootstrap.Extensions.Logger` |
| `Microsoft.Extensions.Caching.Memory` | `Framework.RedisClient.StackExchange` via SCB |
| `IConfiguration.GetSection().Bind()` | `RegisterAutoUpdatedConfiguration<T>` + CCM + SCB |
| Manual `appsettings.{env}.json` per env | CCM (etcd) for runtime config, KeyVault for secrets, SCB for infra |
| `builder.Services.AddSwaggerGen()` (vanilla) | `RegisterSwagger(configuration)` from template `StartupExtensions` |
| Custom auth middleware from scratch | `AppSecretAuthenticationMiddleware` from template (global pipeline auth) |
| `WebApplication.CreateBuilder()` alone | Full `ConfigureHost()` with `AddFrameworkLogger`, `AddCcm`, `AddScb`, `AddKeyVaultProvider` |
| Raw `HttpClient` without resilience | `IHttpClientFactory` + Polly `ResiliencePipeline` (retry + timeout + circuit breaker). See `trading-data-api` for typed client pattern and `trading-opstool-api` for Polly v8 pipeline |
| `Framework.FaultTolerance` for HTTP calls | `Framework.FaultTolerance` is for SQL retry only (uses Enterprise Library `RetryPolicy` with SQL error detection strategies). For HTTP resilience use Polly directly |
| Custom health check implementations | `Bootstrap.HealthCheck` + `Application.HealthCheck.Extensions` (wire via `ConfigureHealthChecks()` in Program.cs) |
| `dotnet new classlib/webapi` | Scaffold from `templates/eToro-Service/` and rename |

> **IMPORTANT — Types that do NOT exist in Trading NuGets (verified via GitHub source audit):**
> - `MonitorWrapper` — does not exist in trading-framework, trading-shared, or trading-core. For metrics, use `IMetrics` (Counter/Gauge/Timer) from `Framework.Metrics` directly.
> - `AuthorizationConfiguration` — not shipped in any NuGet package. Must be defined per-service (template provides one in `Api/Configuration/`).
> - `IEnvironmentConfig` — not an interface in any NuGet. Some services define this locally.
> - `HealthChecksConfig` — not a class in any NuGet. The NuGet provides `HealthChecksConfigurationExtensions.ConfigureHealthChecks()` method.
> - REST provider base class — `Infrastructure.Providers` contains domain-specific providers (InstrumentPriceProvider, SettlementProvider, etc.), NOT a generic HTTP provider base class. Build REST providers with `IHttpClientFactory` + `HttpClient`.

---

## Service Scaffolding (NON-NEGOTIABLE)

ALL new Trading services MUST be scaffolded from `templates/eToro-Service/` in the [trading-templates](https://github.com/eToro/trading-templates) repository. DO NOT create projects from scratch using `dotnet new`.

```bash
dotnet new -i eToro.Trading.Templates
dotnet new etoroservice -n {ServiceName} -o {FolderPath} [options]
```

| Flag | Name | Default | Description |
|------|------|---------|-------------|
| `-is` | install-swagger | `false` | Add Swagger/OpenAPI |
| `-iws` | include-worker-service | `false` | Add background worker |
| `-iasa` | include-app-secret-auth | `false` | Add AppSecret auth middleware |
| `-id` | include-db | `false` | Add database access layer |
| `-ir` | include-rabbit | `false` | Add RabbitMQ messaging |
| `-inr` | include-redis | `false` | Add Redis caching |

---

## Configuration — Trading CCM/KeyVault/SCB Implementation

Trading services use three config sources — NOT vanilla `appsettings.json` binding:

| Source | Purpose | Package |
|--------|---------|---------|
| **CCM** (etcd) | Dynamic runtime config | `eToro.Trading.Configuration.Providers.Ccm` |
| **KeyVault** | Secrets (connection strings, API keys) | `eToro.Trading.Configuration.Providers.KeyVault` |
| **SCB** | Service config broker (RabbitMQ, Redis, env) | `eToro.Trading.Configuration.Providers.Scb` |

**`appsettings.json`** MUST contain ONLY CCM bootstrap config (KeyVaults + Etcds). All app config via CCM.

> See team skill: `team/config-ccm` for complete configuration patterns.

---

## Testing Stack (NON-NEGOTIABLE)

**Stack**: xUnit 2.x, Moq 4.x, **FluentAssertions 6.x** (MUST use for ALL assertions).

**Test projects**: `{ServiceName}.Application.Tests` (required), `{ServiceName}.Infrastructure.Tests` (optional).

**Naming**: Tests are named after the service class: `CalculatedFeesServiceTests`, NOT `CalculatedFeesControllerTests`.

> See team skill: `team/component-testing` for xUnit + FluentAssertions patterns.

---

## Monitoring — Trading Logging & Metrics

### Logging
Use `Framework.Log.ILogger<T>` with `log4net.config` — NOT `Microsoft.Extensions.Logging`. Register via `AddFrameworkLogger(new LoggerWrapper())` + `RegisterGenericFrameworkLoggers()` from `eToro.Trading.Bootstrap.Logger` namespace.

**ILogger method signatures** (from `Framework.Log`):
- `LogDebug(string message)` / `LogDebug(string message, object entry, [CallerMemberName] caller)`
- `LogInfo(string message)` / `LogInfo(string message, object entry, [CallerMemberName] caller)`
- `LogWarn(string message)` / `LogWarn(string message, object entry, [CallerMemberName] caller)`
- `LogError(string message)` / `LogError(string message, Exception exception)` / `LogError(string message, object entry, Exception exception)`
- `LogFatal(string message)` / `LogFatal(string message, Exception exception)`

Every async method SHOULD log entry (sanitized inputs), exit (result summary), and exceptions (full context).

| Level | Method | Usage |
|-------|--------|-------|
| FATAL | `LogFatal` | Application-ending errors |
| ERROR | `LogError` | Unhandled exceptions |
| WARN | `LogWarn` | Handled exceptions, degraded service |
| INFO | `LogInfo` | Request/response summaries |
| DEBUG | `LogDebug` | Detailed flow (dev only) |

### Metrics
Use `IMetrics` from `Framework.Metrics` for StatsD-based metrics. There is **no MonitorWrapper** in any Trading NuGet — emit metrics directly:

```csharp
_metrics.Timer("service.method_name", "duration", elapsedMs);
_metrics.Counter("service.method_name", "invocations");
_metrics.Counter("service.method_name.errors", "errors");
```

> See team skill: `team/monitoring-logging` for Framework.Log and IMetrics patterns.

---

## Authentication — Trading Implementation (NON-NEGOTIABLE)

### AppSecret Authentication (Service-to-Service)
- `AppSecretAuthenticationMiddleware` in `WebApi/Middlewares/` (provided by template) — validates `Authorization` header globally for all controller routes
- `AuthorizationConfiguration` defined per-service in `Api/Configuration/` with `AppSecret`, `ReadOnlyAppSecret`, `ReadWriteAppSecret` properties
- Invalid/missing key → HTTP 401

### `[AuthorizeLevel]` Attribute (Opstool-specific)
> **WARNING**: The `[AuthorizeLevel]` attribute shown in `.reference/` depends on Opstool-specific types (`eToro.Trading.Opstool.Application.Authorization.*`). It is only available in services that reference the Opstool NuGet packages. For services NOT using Opstool, authentication is handled globally by `AppSecretAuthenticationMiddleware` — no per-action attribute is needed.

### STS Token Authentication (Client-Facing)
- `[Authentication]` attribute on client-facing controller actions
- GCID from token for user identity
- Requires STS configuration in bootstrap

> See team skill: `team/api-controllers` for full auth patterns.

---

## Request Validation — FluentValidation (NON-NEGOTIABLE)

Trading uses **FluentValidation** for all request validation:

```csharp
public sealed class InstrumentValidator : AbstractValidator<InstrumentDto>
{
    public InstrumentValidator()
    {
        RuleFor(x => x.InstrumentId).GreaterThan(0).WithMessage("InstrumentId must be > 0");
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
    }
}
```

Register validators in bootstrap: `services.AddValidatorsFromAssemblyContaining<InstrumentValidator>()`. Invoke validation in controllers via injected `IValidator<T>` and `ValidateAsync()`, or use a `FluentValidationActionFilter` to auto-validate requests.

> **Note**: `APIRequestValidationService` is Opstool-specific. For services not using Opstool, use `IValidator<T>` directly.

---

## Type Preferences (NON-NEGOTIABLE)

| Use | Avoid | Reason |
|-----|-------|--------|
| `sealed class` | `record`, `record class` | Serialization, mocking |
| `interface` | Abstract class | Testability, DI |

```csharp
// CORRECT
public sealed class InstrumentDto { public int InstrumentId { get; set; } }

// FORBIDDEN
public record InstrumentDto(int InstrumentId);
```

---

## Quality Gates (NON-NEGOTIABLE)

Task breakdown MUST include `[GATE]` tasks per phase. Each phase ends with `dotnet build` + `dotnet test`.

**Required Gate Tasks Per Phase:**

| Phase | Required Gate Tasks |
|-------|---------------------|
| Phase 0 (Baseline) | `[GATE] Verify workspace clean`, `[GATE] Record baseline` |
| Phase 1+ (Each Phase) | `[GATE] dotnet build`, `[GATE] dotnet test` |
| Final Phase | `[GATE] Final build`, `[GATE] Final test`, `[GATE] Constitution compliance audit` |

---

## CRUD Endpoint Patterns

| HTTP | Route Pattern | Auth |
|------|--------------|------|
| GET (list) | `api/v1/{resources}` | `[AuthorizeLevel]` or `[Authentication]` |
| GET (detail) | `api/v1/{resources}/{id}` | `[AuthorizeLevel]` or `[Authentication]` |
| POST (create) | `api/v1/{resources}` | `[AuthorizeLevel(ReadWrite)]` or `[Authentication]` |
| PUT (update) | `api/v1/{resources}/{id}` | `[AuthorizeLevel(ReadWrite)]` or `[Authentication]` |
| DELETE | `api/v1/{resources}/{id}` | `[AuthorizeLevel(ReadWrite)]` or `[Authentication]` |

---

## Code Style & Naming Conventions

| Component | Pattern | Example |
|-----------|---------|---------|
| Solution | `{ServiceName}.sln` | `TradingOpsToolApi.sln` |
| Controller | `{Feature}Controller` | `InstrumentsController` |
| Service Interface | `I{Feature}Service` | `ICalculatedFeesService` |
| Service Class | `{Feature}Service` | `CalculatedFeesService` |
| Repository Interface | `I{Feature}Repository` | `IInstrumentRepository` |
| Repository Class | `Db{Feature}Repository` | `DbInstrumentRepository` |
| Mapper Profile | `{Feature}MappingProfile` | `InstrumentMappingProfile` |
| Validator | `{Feature}Validator` | `InstrumentValidator` |
| Entity | `{Feature}` | `Instrument`, `FeeConfiguration` |
| DTO | `{Feature}Dto` | `InstrumentDto`, `FeeConfigDto` |

**Class Member Ordering**: Constants, Static fields, Instance fields, Constructors, Public properties, Public methods, Protected methods, Private methods. ALL public members BEFORE all private members.

**Dictionary Naming**: Use `{Key}To{Value}`: `InstrumentIdToInstrument`, NOT `ById`.

---

## Template Files: KEEP vs Reference (NON-NEGOTIABLE)

**KEEP files** (already in the project — do NOT modify, delete, or reimplement):

| File | Why |
|------|-----|
| `WebApi/Middlewares/ExceptionHandlingMiddleware.cs` | Centralized error handling with `application/problem+json` |
| `WebApi/Middlewares/AppSecretAuthenticationMiddleware.cs` | AppSecret header validation |
| `WebApi/Extensions/StartupExtensions.cs` | `ConfigureWebService()`, `ConfigureWebApplication()`, `RegisterSwagger()` |

**Reference files** (in `.reference/` folder — agents read for implementation patterns):

| File | Pattern to follow |
|------|-------------------|
| `.reference/Api/Controllers/ExampleController.cs` | Controller with FluentValidation, AutoMapper, Internalize/Externalize, sub-resource routes |
| `.reference/Api/Dto/Requests/GetExampleRequest.cs` | Request DTO with `[FromQuery]` properties |
| `.reference/Api/Dto/Responses/GetExampleResponse.cs` | Response DTO |
| `.reference/Api/Validators/GetExampleRequestValidator.cs` | FluentValidation with ErrorCode |
| `.reference/Api/Extensions/ExampleRequestExtensions.cs` | Internalize pattern |
| `.reference/Api/Extensions/ExampleResponseExtensions.cs` | Externalize pattern |
| `.reference/Api/Mapper/ExampleMappingProfile.cs` | AutoMapper profile |
| `.reference/Bootstrap/Bootstrappers/BasicBootstrap.cs` | DI registration pattern |
| `.reference/Bootstrap/Bootstrappers/ConfigurationsBootstrap.cs` | `RegisterAutoUpdatedConfiguration` with sub-configs |
| `.reference/Bootstrap/Bootstrappers/HealthCheckBootstrap.cs` | Health check registration |
| `.reference/Infrastructure/Providers/Interfaces/IExampleApiProvider.cs` | REST provider interface |
| `.reference/Infrastructure/Providers/Concrete/ExampleApiProvider.cs` | HttpClient + Polly ResiliencePipeline provider |
| `.reference/Infrastructure/Repositories/ExampleRepository.cs` | BaseRepository + stored procedure pattern |
| `.reference/Infrastructure/Repositories/ExampleCachedRepository.cs` | Scrutor decorator caching pattern |

---

## Security Review Gate (NON-NEGOTIABLE)

Every service MUST pass the Security Agent review after plan completion and before task generation. The review evaluates data classification, cluster placement, authentication, PII handling, dependency sensitivity, and service type against the Security Agent MVP Ruleset. The plan.md MUST include a **Service Security Profile** section with mandatory declarations — this is the primary input for security validation before any code exists.

- **Auto-approved** services proceed to implementation
- **Auto-rejected** services MUST resolve all violations before proceeding
- **Manual-review** services require security architect sign-off

The Cytech agent GitHub Action enforces the same rules on PR, blocking merge for Auto-reject verdicts.

> See core skill: `security-review` for the complete ruleset. See core skill: `cluster-deployment` for cluster placement validation.

---

## Anti-patterns — Trading-Specific (DO NOT DO)

- Using `Microsoft.Extensions.Logging.ILogger<T>` instead of `Framework.Log.ILogger<T>`
- Using `record` types for DTOs or services
- Skipping FluentValidation validators for request DTOs
- Missing AutoMapper profiles for entity-to-DTO mapping
- Creating services from scratch instead of scaffolding from `templates/eToro-Service/`
- Using vanilla `appsettings.{env}.json` instead of CCM + KeyVault + SCB
- Using NUnit/Shouldly instead of xUnit/FluentAssertions
- Hardcoding Trading NuGet versions instead of using `$(VersionVariable)` in `.csproj`
- Missing `shared.props` at repo root
- Missing `[GATE]` tasks in task breakdown
- Using `[controller]` token in route attributes
- Using singular resource names in routes
- Repository implementations in Domain layer
- Direct `WebApplication.CreateBuilder()` without `ConfigureHost()`
- Pattern invention — creating abstractions not in eToro Trading codebase

---

## Governance

This team constitution extends `constitution.md`. Both MUST be loaded together. Amendments to this file do NOT require changes to constitution.md.

**Version**: 2.0.0 | **Derived from**: trading-templates constitution v3.2.1 | **Updated**: GitHub NuGet source audit (trading-framework, trading-shared, trading-core)
