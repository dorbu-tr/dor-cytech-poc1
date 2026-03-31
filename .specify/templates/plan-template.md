# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

**Language/Version**: C# / .NET 8.0
**Primary Dependencies**: Infrastructure NuGets (see checklist below)
**Storage**: [TBD based on requirements - Cosmos DB, Redis, etc.]
**Testing**: NUnit, Moq, Shouldly (see team constitution for versions)
**Target Platform**: Linux container (Kubernetes)
**Project Type**: ASP.NET Core Web API (layered architecture)
**Performance Goals**: [NEEDS CLARIFICATION - e.g., 1000 req/s, <100ms p95]
**Constraints**: [NEEDS CLARIFICATION - e.g., <200ms p95, rate limits]
**Scale/Scope**: [NEEDS CLARIFICATION - e.g., concurrent users, data volume]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [ ] Plan before code principle verified
- [ ] Bottom-up layering order defined (Interfaces → Domain → Infrastructure → Application → Api)
- [ ] Quality gates defined for each phase (component tests only - NOT system tests)
- [ ] Testing plan includes Component tests (run) and System tests (write only - DO NOT run locally)
- [ ] External dependencies verification defined
- [ ] Logging discipline established
- [ ] Infrastructure NuGets checklist reviewed
- [ ] API Discovery checked for internal services
- [ ] Monitoring wrapper usage planned for all public async methods
- [ ] Class size limits acknowledged (~200 lines max)
- [ ] **Controller Method Pattern (Section XI)**: Controllers use single request object, NO `[FromQuery]`/`[FromRoute]`/`[FromBody]` on method params

## Security Review Gate

*GATE: Run `/speckit.cytech-plan` after plan completion. Must resolve before `/speckit.tasks`.*
*These declarations are MANDATORY — the Cytech agent validates them on PR before any code exists.*

### Service Security Profile (must be filled by the developer)

- **Data Classification**: [Public / Internal / Confidential / Restricted]
- **Service Type**: [Stateless / Internal tooling / Wrapper-proxy / Approved twin / Config-only / QA-mock / Other]
- **Target Cluster**: [Front (31) / BE (21) / BE with eToroDB (11) / Trading / Money]
- **eToroDB Access**: [Yes / No] — if Yes, list databases
- **PII Handling**: [None / Read-only / Storage / Processing] — if any, list data fields
- **Sensitive Dependencies**: [None / List services that handle sensitive/confidential data]
- **Authentication Model**: [STS client-facing / API Key backend / AppSecret / Mixed / None]
- **External-Facing Endpoints**: [Yes / No] — if Yes, list endpoints and data sensitivity
- **PCI Scope**: [Yes / No]

### Security Validation Checklist

- [ ] Data classification declared and justified
- [ ] Cluster placement matches service type (per `cluster-deployment` skill)
- [ ] Authentication documented for all endpoints exposing private data
- [ ] PII handling inventory completed (or confirmed as None)
- [ ] Dependency sensitivity assessment completed
- [ ] Service type qualification identified
- [ ] Security review verdict: [Auto-approve / Auto-reject / Manual review]

<!-- TEAM-SPECIFIC: START - Replace this section with your team's required NuGet packages -->
## Infrastructure NuGets Checklist

| NuGet Package | Required | MCP Checked | Notes |
|--------------|----------|-------------|-------|
| `eToro.Infrastructure.CentralConfigurationManager` | ✅ Yes | [ ] | CCM configuration |
| `eToro.Infrastructure.Monitoring.Mvc` | ✅ Yes | [ ] | Monitoring, health endpoints |
| `eToro.Infrastructure.Logging` | ✅ Yes | [ ] | Structured logging |
| `eToro.Infrastructure.Metrics` | ✅ Yes | [ ] | Metrics and KPIs |
| `eToro.Infrastructure.Providers.Rest.Mvc` | [ ] | [ ] | REST provider base classes |
| `eToro.Infrastructure.Caching` | [ ] | [ ] | In-memory and Redis caching |
| `eToro.Infrastructure.Static.Caching` | [ ] | [ ] | Preloaded caches |
| `eToro.Infrastructure.Auth.Sts` | [ ] | [ ] | Token validation |
| `eToro.Infrastructure.Auth.Sts.Mvc` | [ ] | [ ] | MVC STS integration |
| `eToro.Infrastructure.ExternalUserIds` | [ ] | [ ] | Encrypted user identifiers |
| `eToro.Infrastructure.Messaging.ServiceBus` | [ ] | [ ] | Azure Service Bus |
| `eToro.Infrastructure.Messaging.RabbitMq` | [ ] | [ ] | RabbitMQ messaging |
| `eToro.Infrastructure.Providers.DocumentDb.Cosmos` | [ ] | [ ] | Cosmos DB data access |
| `eToro.Infrastructure.SubAccounts` | [ ] | [ ] | Sub-account handling |
| `eToro.Infrastructure.Tests.Component` | ✅ Yes | [ ] | Component test infrastructure |
| `eToro.Infrastructure.Tests.System` | ✅ Yes | [ ] | System test infrastructure |
<!-- TEAM-SPECIFIC: END -->

## API Discovery Checklist

| Internal Service | Discovery Status | Provider Created | Health Check | Mock Provider |
|-----------------|------------------|------------------|--------------|---------------|
| [Service 1] | [ ] Discovered | [ ] | [ ] | [ ] |
| [Service 2] | [ ] Discovered | [ ] | [ ] | [ ] |

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (eToro C# Standard Layout)

```text
dor-cytech-poc1.Api.sln
├── dor-cytech-poc1.Api/                    # 1 - User Interface
│   ├── Bootstrap/
│   │   ├── Program.cs
│   │   └── Startup.cs
│   ├── Controllers/
│   ├── Dto/
│   │   ├── Requests/         # Request DTOs with Validate()
│   │   │   └── Body/        # Request body classes with their own Validate()
│   │   ├── Responses/        # Top-level response DTOs ONLY
│   │   └── Data/             # Nested complex objects within responses (NO Response suffix — e.g., ApplicationItem, NOT ApplicationResponseData)
│   ├── Extensions/
│   ├── Factories/
│   ├── Constants/             # ErrorMessageConsts, FieldsMaxLength
│   ├── Enumerations/          # ErrorCode enum (NOT in Domain — this is API validation concern)
│   ├── Exceptions/            # RequestValidationException
│   ├── Properties/launchSettings.json
│   ├── appsettings.json
│   └── dor-cytech-poc1.Api.csproj
├── dor-cytech-poc1.Application/            # 2 - Application
│   ├── Services/
│   │   ├── Interfaces/
│   │   └── Concrete/
│   ├── Builders/
│   ├── Dto/Parameters/
│   ├── Dto/Results/          # Dedicated result per service method (NEVER raw List<T>)
│   ├── Dto/Data/             # Shared data objects (e.g., ApplicationData)
│   ├── Exceptions/
│   ├── Extensions/
│   ├── Health/
│   ├── Helpers/
│   ├── Jobs/
│   └── dor-cytech-poc1.Application.csproj
├── dor-cytech-poc1.Domain/                 # 3 - Domain
│   ├── Constants/
│   ├── Dto/
│   ├── Enumerations/
│   └── dor-cytech-poc1.Domain.csproj
├── dor-cytech-poc1.Infrastructure/         # 4 - Infrastructure
│   ├── Providers/Interfaces/
│   ├── Providers/Abstract/
│   ├── Providers/Concrete/
│   ├── Repositories/Interfaces/
│   ├── Repositories/Concrete/
│   ├── Dto/
│   ├── Exceptions/
│   └── dor-cytech-poc1.Infrastructure.csproj
├── dor-cytech-poc1.Tests.Common.Domain/    # 5 - Tests Common
│   ├── Dto/
│   └── dor-cytech-poc1.Tests.Common.Domain.csproj
├── dor-cytech-poc1.Tests.Common.Infrastructure/
│   ├── Providers/
│   ├── Helpers/
│   └── dor-cytech-poc1.Tests.Common.Infrastructure.csproj
├── dor-cytech-poc1.Tests.Component/        # 5.2 - Component Tests
│   ├── Tests/Abstract/TestsBase.cs
│   ├── Bootstrap/
│   │   ├── ComponentTestBootstrapper.cs
│   │   └── Startup.cs
│   ├── Constants/
│   ├── Extensions/
│   ├── Models/
│   ├── Tests/
│   └── dor-cytech-poc1.Tests.Component.csproj
├── dor-cytech-poc1.Tests.System/           # 5.4 - System Tests
│   ├── Bootstrap/SystemTestBootstrapper.cs
│   ├── Tests/
│   ├── appsettings.*.json
│   └── dor-cytech-poc1.Tests.System.csproj
├── dor-cytech-poc1.Tests.System.Domain/
│   └── dor-cytech-poc1.Tests.System.Domain.csproj
└── dor-cytech-poc1.Tests.System.Infrastructure/
    ├── Providers/
    └── dor-cytech-poc1.Tests.System.Infrastructure.csproj
```

## Phase Breakdown

### Phase 0: Planning & Research
- [ ] FR/NFR specification complete
- [ ] Architecture plan approved
- [ ] API Discovery MCP queries executed
- [ ] Infra NuGets MCP documentation reviewed

### Phase 1: Interfaces / Contracts
- [ ] All interface definitions created
- [ ] DTOs defined
- [ ] Error schemas defined

### Phase 2: Domain Layer
- [ ] Pure entities created
- [ ] Domain enumerations defined (e.g., `ApplicationType`, `ResourceStatus` — business concepts only)
- [ ] Constants established
- [ ] NOTE: `ErrorCode` is NOT a domain concept — it belongs in `Api/Enumerations/` (see Phase 5)

### Phase 3: Infrastructure Layer
- [ ] Provider interfaces implemented
- [ ] Repository implementations
- [ ] External API integrations

### Phase 4: Application Layer (BL)
- [ ] Service interfaces and implementations
- [ ] **Every service method returns a dedicated Result DTO** — e.g., `GetResourcesResult`, NEVER `Task<List<T>>`. Collections wrapped as properties.
- [ ] Parameters DTOs in `Application/Dto/Parameters/`, Results DTOs in `Application/Dto/Results/`
- [ ] Shared data objects in `Application/Dto/Data/` (e.g., `ApplicationData`, `ResourceData`)
- [ ] Application exceptions: PascalCase error codes (e.g., `"ResourceNotFound"`), static messages, `IDictionary<string, object> data` for context
- [ ] MonitorWrapper on all public async methods — use `async monitorData =>`, log scalar fields to `monitorData.Logs` (counts, IDs, booleans — NEVER entire objects)
- [ ] Business logic complete

### Phase 5: Api Layer (Facade)
- [ ] `ErrorCode` enum in `Api/Enumerations/` — PascalCase names, NO numeric values (NOT in Domain)
- [ ] `ErrorMessageConsts` in `Api/Constants/` — reusable format strings
- [ ] `FieldsMaxLength` in `Api/Constants/` — max length constants for string validation
- [ ] Request DTOs with `[FromRoute]`/`[FromQuery]`/`[FromBody]` on **properties** (NOT method params) and `Validate()` methods
- [ ] Body classes with their own `Validate()` — parent delegates, NEVER validates body fields inline
- [ ] Nested complex objects in `Api/Dto/Data/` — NOT in `Dto/Responses/`, NO `Response` suffix
- [ ] Controllers using **single request object** per method (Constitution Section XI)
- [ ] `Internalize()`/`Externalize()` extension methods
- [ ] DI bootstrap configured
- [ ] Health endpoints exposed

### Phase 6: Testing
- [ ] Component tests complete and passing
- [ ] System tests written (DO NOT run locally - CI/CD handles execution)
- [ ] All gates passing (component tests only)

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., Additional layer] | [current need] | [why standard approach insufficient] |
