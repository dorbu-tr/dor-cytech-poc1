# Implementation Plan: Trading Positions API

**Branch**: `001-trading-positions-api` | **Date**: 2026-03-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-trading-positions-api/spec.md`

## Summary

Build a Trading Positions API aggregator service that proxies and enriches position data from two upstream internal APIs (Positions API and Instruments API). The service exposes three endpoints — list positions with cursor-based pagination and optional instrument filtering, get position details, and close a position — all authenticated via STS tokens. The service follows the aggregator pattern (no database) using `IHttpClientFactory` + Polly resilience pipelines for upstream calls, with graceful degradation when the Instruments API is unavailable.

## Technical Context

**Language/Version**: C# / .NET 8.0
**Primary Dependencies**: Trading NuGets (trading-core, trading-shared, trading-framework), Polly v8, FluentValidation 11.x, AutoMapper 12.x, Swashbuckle 6.x
**Storage**: None — this is an aggregator service (no database). All data sourced from upstream Positions API and Instruments API.
**Testing**: xUnit, Moq, FluentAssertions (per team constitution)
**Target Platform**: Linux container (Kubernetes / AKS)
**Project Type**: ASP.NET Core Web API — Aggregator service (calls external APIs only, no DB)
**Architecture Pattern**: Follow `trading-data-api` pattern — IHttpClientFactory + typed clients + Polly ResiliencePipeline
**Performance Goals**: GET endpoints <150ms p95; POST close <300ms p95 (NFR-001, NFR-002)
**Constraints**: Circuit breaker + retry + timeout for both upstream APIs. Graceful degradation when Instruments API is down. Class sizes <200 lines.
**Scale/Scope**: Standard trading service scale. No PII stored — users referenced by internal ID from STS token only.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Plan before code principle verified
- [x] Bottom-up layering order defined (Interfaces → Domain → Infrastructure → Application → Api)
- [x] Quality gates defined for each phase (component tests only - NOT system tests)
- [x] Testing plan includes Component tests (run) and System tests (write only - DO NOT run locally)
- [x] External dependencies verification defined (Positions API, Instruments API — both need contract, mock, health check)
- [x] Logging discipline established (Framework.Log.ILogger<T>, structured logging, no PII)
- [x] Infrastructure NuGets checklist reviewed (see below)
- [x] API Discovery checked for internal services (Positions API, Instruments API — see checklist below)
- [x] Monitoring via Framework.Metrics IMetrics planned for all async service methods (no MonitorWrapper in Trading NuGets)
- [x] Class size limits acknowledged (~200 lines max)
- [x] **Controller Method Pattern (Section XI)**: Controllers use single request object, NO `[FromQuery]`/`[FromRoute]`/`[FromBody]` on method params

## Security Review Gate

*GATE: Run `/speckit.cytech-plan` after plan completion. Must resolve before `/speckit.tasks`.*
*These declarations are MANDATORY — the Cytech agent validates them on PR before any code exists.*

### Service Security Profile (must be filled by the developer)

- **Data Classification**: Internal
- **Service Type**: Wrapper-proxy (aggregates and enriches data from two upstream internal APIs)
- **Target Cluster**: Trading
- **eToroDB Access**: No
- **PII Handling**: None — users referenced solely by internal ID extracted from STS token. No PII stored, logged, or processed.
- **Sensitive Dependencies**: None — Positions API and Instruments API are internal services handling trading data (not PCI/financial secrets directly)
- **Authentication Model**: STS client-facing (all three endpoints require STS token authentication)
- **External-Facing Endpoints**: Yes — all three endpoints are client-facing (authenticated users):
  - `GET /api/v1/positions` — returns user's position list (Internal data)
  - `GET /api/v1/positions/{positionId}` — returns position detail (Internal data)
  - `POST /api/v1/positions/{positionId}/close` — closes a position (Internal action); accepts optional free-text `reason` field (string, up to 500 chars) for audit trail
- **PCI Scope**: No

### Security Validation Checklist

- [x] Data classification declared and justified — Internal: no PII stored, only internal user IDs from STS tokens
- [x] Cluster placement matches service type — Trading cluster for Trading-domain client-facing wrapper-proxy service
- [x] Authentication documented for all endpoints exposing private data — STS token auth on all three endpoints
- [x] PII handling inventory completed — confirmed as None
- [x] Dependency sensitivity assessment completed — both upstream APIs are internal, non-sensitive
- [x] Service type qualification identified — Wrapper-proxy (aggregator of two internal APIs)
- [x] Security review verdict: **Auto-approve** (Internal data, no PII, no eToroDB, STS auth, Trading cluster, no PCI)

## Infrastructure NuGets Checklist

| NuGet Package | Required | MCP Checked | Notes |
|--------------|----------|-------------|-------|
| `eToro.Trading.Bootstrap.Extensions.Logger` | ✅ Yes | [x] | Framework.Log + LoggerWrapper registration |
| `eToro.Trading.Bootstrap.HealthCheck` | ✅ Yes | [x] | Health check command builders (HTTP-based for aggregator) |
| `eToro.Trading.Bootstrap.Models` | ✅ Yes | [x] | Bootstrap configuration models |
| `eToro.Trading.Configuration.Providers.Ccm` | ✅ Yes | [x] | CCM (etcd) dynamic config |
| `eToro.Trading.Configuration.Providers.KeyVault` | ✅ Yes | [x] | Secrets (API keys for upstream services) |
| `eToro.Trading.Configuration.Providers.Scb` | ✅ Yes | [x] | Service config broker |
| `eToro.Trading.Framework.Configuration` | ✅ Yes | [x] | Framework configuration |
| `eToro.Trading.Framework.Log.Extension.Json` | ✅ Yes | [x] | JSON log serialization |
| `eToro.Trading.Framework.Metrics` | ✅ Yes | [ ] | IMetrics for StatsD-based metrics |
| `eToro.Trading.RetryHandling` | ✅ Yes | [x] | Retry handling utilities |
| `eToro.Trading.Infrastructure.Providers` | ✅ Yes | [x] | Provider base types |
| `eToro.Trading.Application.HealthCheck.Extensions` | ✅ Yes | [x] | Health check registration extensions |
| `AutoMapper.Extensions.Microsoft.DependencyInjection` | ✅ Yes | N/A | AutoMapper DI registration |
| `FluentValidation` | ✅ Yes | N/A | Request validation |
| `FluentValidation.DependencyInjectionExtensions` | ✅ Yes | N/A | Validator DI registration |
| `Polly` | ✅ Yes | N/A | Resilience pipeline (retry + timeout + circuit breaker) |
| `Polly.Extensions` | ✅ Yes | N/A | Polly DI extensions |
| `Microsoft.Extensions.Http` | ✅ Yes | N/A | IHttpClientFactory for REST providers |
| `Swashbuckle.AspNetCore` | ✅ Yes | N/A | Swagger/OpenAPI docs |
| `eToro.Trading.Sql.DbAccess` | ❌ No | N/A | Not needed — aggregator, no DB |
| `eToro.Trading.Sql.Persistors` | ❌ No | N/A | Not needed — aggregator, no DB |
| `eToro.Trading.Domain.Repositories` | ❌ No | N/A | Not needed — aggregator, no DB |
| `eToro.Trading.Infrastructure.Repositories` | ❌ No | N/A | Not needed — aggregator, no DB |
| `Scrutor` | ❌ No | N/A | Not needed — no cached repository decoration |

## API Discovery Checklist

| Internal Service | Discovery Status | Provider Created | Health Check | Mock Provider |
|-----------------|------------------|------------------|--------------|---------------|
| Positions API | [ ] Discovered | [ ] | [ ] | [ ] |
| Instruments API | [ ] Discovered | [ ] | [ ] | [ ] |

## Project Structure

### Documentation (this feature)

```text
specs/001-trading-positions-api/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── openapi.yaml     # OpenAPI 3.0 spec for all endpoints
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (Unified Template Layout — Bootstrap merged into Api)

```text
dor-cytech-poc1.Api.sln
├── src/
│   ├── dor-cytech-poc1.Api/                        # API + Bootstrap (composition root)
│   │   ├── Bootstrap/
│   │   │   ├── Program.cs
│   │   │   └── Startup.cs
│   │   ├── Bootstrappers/
│   │   │   ├── BasicBootstrap.cs                   # DI: services, providers, mappers, validators, loggers
│   │   │   ├── ConfigurationsBootstrap.cs          # CCM auto-updated config registration
│   │   │   ├── HealthCheckBootstrap.cs             # HTTP health checks for both upstream APIs
│   │   │   ├── HttpClientBootstrap.cs              # IHttpClientFactory typed clients + Polly
│   │   │   └── RetryPolicyBootstrap.cs             # Polly ResiliencePipeline registration
│   │   ├── Configuration/
│   │   │   ├── AuthorizationConfiguration.cs       # AppSecret config (template-provided)
│   │   │   ├── PositionsApiConfiguration.cs        # Positions API URL, timeout, health check URL
│   │   │   └── InstrumentsApiConfiguration.cs      # Instruments API URL, timeout, health check URL
│   │   ├── Controllers/
│   │   │   └── PositionsController.cs              # 3 actions: GetAll, GetById, Close
│   │   ├── Dto/
│   │   │   ├── Requests/
│   │   │   │   ├── GetPositionsRequest.cs          # [FromQuery] cursor, pageSize, instrumentId
│   │   │   │   ├── GetPositionByIdRequest.cs       # [FromRoute] positionId
│   │   │   │   └── ClosePositionRequest.cs         # [FromRoute] positionId + [FromBody] body
│   │   │   ├── Responses/
│   │   │   │   ├── GetPositionsResponse.cs         # Items + pagination cursor
│   │   │   │   ├── GetPositionDetailResponse.cs    # Full position detail
│   │   │   │   └── ClosePositionResponse.cs        # Close result
│   │   │   └── Data/
│   │   │       ├── PositionItem.cs                 # Position summary in list
│   │   │       ├── PositionDetail.cs               # Full position detail
│   │   │       ├── InstrumentInfo.cs               # Instrument enrichment data
│   │   │       └── PaginationCursor.cs             # Cursor-based pagination metadata
│   │   ├── Extensions/
│   │   │   ├── PositionsRequestExtensions.cs       # Internalize() for all request DTOs
│   │   │   └── PositionsResponseExtensions.cs      # Externalize() for all result DTOs
│   │   ├── Mapper/
│   │   │   └── PositionsMappingProfile.cs          # AutoMapper profile
│   │   ├── Validators/
│   │   │   ├── GetPositionsRequestValidator.cs     # FluentValidation for list request
│   │   │   ├── GetPositionByIdRequestValidator.cs  # FluentValidation for detail request
│   │   │   └── ClosePositionRequestValidator.cs    # FluentValidation for close request
│   │   ├── Constants/
│   │   │   ├── ErrorMessageConsts.cs               # Reusable format strings
│   │   │   └── FieldsMaxLength.cs                  # String max lengths
│   │   ├── Enumerations/
│   │   │   └── ErrorCode.cs                        # API error codes (PascalCase, no numeric values)
│   │   ├── Exceptions/
│   │   │   └── RequestValidationException.cs       # Validation exception type
│   │   ├── ActionFilters/
│   │   │   └── FluentValidationActionFilter.cs     # Template-provided
│   │   ├── Middlewares/
│   │   │   ├── AppSecretAuthenticationMiddleware.cs # Template-provided
│   │   │   └── ExceptionHandlingMiddleware.cs      # Template-provided
│   │   ├── Extensions/
│   │   │   └── StartupExtensions.cs                # Template-provided
│   │   ├── appsettings.json
│   │   └── dor-cytech-poc1.Api.csproj
│   ├── dor-cytech-poc1.Application/                # Application layer
│   │   ├── Services/
│   │   │   ├── Interfaces/
│   │   │   │   └── IPositionsService.cs
│   │   │   └── Concrete/
│   │   │       └── PositionsService.cs             # Orchestrates providers, enrichment, metrics
│   │   ├── Dto/
│   │   │   ├── Parameters/
│   │   │   │   ├── GetPositionsParameters.cs
│   │   │   │   ├── GetPositionByIdParameters.cs
│   │   │   │   └── ClosePositionParameters.cs
│   │   │   ├── Results/
│   │   │   │   ├── GetPositionsResult.cs           # Wraps collection + pagination
│   │   │   │   ├── GetPositionDetailResult.cs
│   │   │   │   └── ClosePositionResult.cs
│   │   │   └── Data/
│   │   │       ├── PositionData.cs                 # Enriched position data
│   │   │       └── InstrumentData.cs               # Instrument reference data
│   │   ├── Exceptions/
│   │   │   ├── PositionNotFoundException.cs
│   │   │   └── PositionNotOpenException.cs         # 409 Conflict
│   │   ├── Mapper/
│   │   │   └── PositionsMappingProfile.cs          # Application-level mappings
│   │   └── dor-cytech-poc1.Application.csproj
│   ├── dor-cytech-poc1.Domain/                     # Domain layer (enumerations only)
│   │   ├── Enumerations/
│   │   │   ├── PositionStatus.cs                   # Open, Closed
│   │   │   └── CloseReason.cs                      # UserRequested, StopLoss, TakeProfit, MarginCall, Other
│   │   └── dor-cytech-poc1.Domain.csproj
│   └── dor-cytech-poc1.Infrastructure/             # Infrastructure layer
│       ├── Providers/
│       │   ├── Interfaces/
│       │   │   ├── IPositionsApiProvider.cs
│       │   │   └── IInstrumentsApiProvider.cs
│       │   ├── Concrete/
│       │   │   ├── PositionsApiProvider.cs          # IHttpClientFactory + Polly
│       │   │   └── InstrumentsApiProvider.cs        # IHttpClientFactory + Polly
│       │   └── Dto/
│       │       ├── Requests/
│       │       │   └── Positions/
│       │       │       └── ClosePositionRequest.cs  # Upstream close request body
│       │       └── Responses/
│       │           ├── Positions/
│       │           │   ├── GetPositionsResponse.cs
│       │           │   ├── GetPositionDetailResponse.cs
│       │           │   └── ClosePositionResponse.cs
│       │           └── Instruments/
│       │               └── GetInstrumentResponse.cs
│       └── dor-cytech-poc1.Infrastructure.csproj
├── Tests/
│   ├── dor-cytech-poc1.Tests.Common.Domain/
│   ├── dor-cytech-poc1.Tests.Common.Infrastructure/
│   │   └── Providers/
│   │       ├── TestPositionsApiProvider.cs          # Mock Positions API
│   │       └── TestInstrumentsApiProvider.cs        # Mock Instruments API
│   ├── dor-cytech-poc1.Tests.Component/
│   │   ├── Bootstrap/
│   │   │   ├── ComponentTestBootstrapper.cs
│   │   │   └── Startup.cs
│   │   └── Tests/
│   │       ├── ListPositionsTests.cs
│   │       ├── GetPositionDetailTests.cs
│   │       └── ClosePositionTests.cs
│   ├── dor-cytech-poc1.Tests.System/
│   │   └── Tests/
│   │       ├── ListPositionsTests.cs
│   │       ├── GetPositionDetailTests.cs
│   │       └── ClosePositionTests.cs
│   ├── dor-cytech-poc1.Tests.System.Domain/
│   └── dor-cytech-poc1.Tests.System.Infrastructure/
│       └── Providers/
│           └── SystemTestApiProvider.cs
└── .reference/                                     # Pattern reference (read-only)
```

## Phase Breakdown

### Phase 0: Planning & Research
- [x] FR/NFR specification complete (see spec.md)
- [x] Architecture plan approved (aggregator pattern — trading-data-api)
- [ ] API Discovery MCP queries executed for Positions API and Instruments API
- [x] Infra NuGets checklist reviewed — DB-related NuGets excluded (aggregator)

### Phase 1: Interfaces / Contracts
- [ ] Provider interfaces defined (IPositionsApiProvider, IInstrumentsApiProvider)
- [ ] Application service interface defined (IPositionsService)
- [ ] All DTOs defined (Parameters, Results, Data, Provider DTOs, Request/Response)
- [ ] Domain enumerations defined (PositionStatus, CloseReason)
- [ ] Error schemas defined (ErrorCode enum, ErrorMessageConsts)
- [ ] OpenAPI contract generated

### Phase 2: Domain Layer
- [ ] `PositionStatus` enumeration created (Open, Closed)
- [ ] `CloseReason` enumeration created (UserRequested, StopLoss, TakeProfit, MarginCall, Other)
- [ ] NOTE: `ErrorCode` is NOT a domain concept — it belongs in `Api/Enumerations/`

### Phase 3: Infrastructure Layer
- [ ] `IPositionsApiProvider` + `PositionsApiProvider` implemented (IHttpClientFactory + Polly)
- [ ] `IInstrumentsApiProvider` + `InstrumentsApiProvider` implemented (IHttpClientFactory + Polly)
- [ ] Provider DTOs defined for both upstream APIs
- [ ] Polly ResiliencePipeline configured (retry + timeout + circuit breaker per API)
- [ ] Typed HttpClient registration for both providers
- [ ] Connectivity verification: call Positions API health endpoint at `http://10.0.5.120:8080/healthcheck` to validate provider wiring during integration setup

### Phase 4: Application Layer (BL)
- [ ] `IPositionsService` / `PositionsService` implemented
- [ ] **Every service method returns a dedicated Result DTO** (GetPositionsResult, GetPositionDetailResult, ClosePositionResult)
- [ ] Parameters DTOs in `Application/Dto/Parameters/`, Results DTOs in `Application/Dto/Results/`
- [ ] Shared data objects in `Application/Dto/Data/` (PositionData, InstrumentData)
- [ ] Application exceptions: PositionNotFoundException, PositionNotOpenException
- [ ] IMetrics instrumentation on all async methods (Timer, Counter, Error counter)
- [ ] Graceful degradation: Instruments API failure → return positions without instrument enrichment
- [ ] Cursor-based pagination logic (pass-through from Positions API)
- [ ] Position ownership validated via userId from STS token

### Phase 5: Api Layer (Facade)
- [ ] `ErrorCode` enum in `Api/Enumerations/` — PascalCase names, NO numeric values
- [ ] `ErrorMessageConsts` in `Api/Constants/` — reusable format strings
- [ ] `FieldsMaxLength` in `Api/Constants/` — max length constants
- [ ] Request DTOs with binding attributes on **properties** (NOT method params)
- [ ] Body class for ClosePositionRequest with its own validation (includes optional free-text `reason` string field, passed directly to upstream Positions API for audit logging)
- [ ] FluentValidation validators for all three requests
- [ ] `PositionsController` using **single request object** per method
- [ ] `Internalize()`/`Externalize()` extension methods
- [ ] AutoMapper profile for result-to-response mapping
- [ ] DI bootstrap configured (BasicBootstrap, ConfigurationsBootstrap, HealthCheckBootstrap, HttpClientBootstrap)
- [ ] Health endpoints exposed (HTTP checks for both upstream APIs)
- [ ] STS authentication on all three endpoints
- [ ] Swagger/OpenAPI documentation with XML docs

### Phase 6: Testing
- [ ] Component tests: ListPositionsTests, GetPositionDetailTests, ClosePositionTests
- [ ] Mock providers: TestPositionsApiProvider, TestInstrumentsApiProvider
- [ ] System tests written (DO NOT run locally - CI/CD handles execution)
- [ ] All gates passing (component tests only)

## Complexity Tracking

> No constitution violations identified. The aggregator pattern is straightforward and fully compliant.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | — | — |
