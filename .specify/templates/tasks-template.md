---
description: "Task list template for feature implementation"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Constitution Compliance**: All tasks MUST follow the constitution at `.specify/memory/constitution.md` + `.specify/memory/constitution-team.md`

> **Reference examples** live in `.reference/` at the repo root. Agents read these for implementation patterns. If the project already has real code for a pattern, agents follow the real code for consistency.

## Format: `[ID] [P?] [Phase] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Phase]**: Which phase this task belongs to (P1-Interfaces, P2-Domain, P3-Infrastructure, P4-Application, P5-Api, P6-Tests)
- Include exact file paths in descriptions

## Path Conventions (eToro C# Standard)

- **Api**: `dor-cytech-poc1.Api/`
- **Application**: `dor-cytech-poc1.Application/`
- **Domain**: `dor-cytech-poc1.Domain/`
- **Infrastructure**: `dor-cytech-poc1.Infrastructure/`
- **Component Tests**: `dor-cytech-poc1.Tests.Component/`
- **System Tests**: `dor-cytech-poc1.Tests.System/`

---

## Phase 0: Planning & Setup

**Purpose**: Project initialization, MCP discovery, and specification


<!-- TEAM-SPECIFIC: START - Replace MCP discovery tasks with your team's discovery process -->
**MCP Discovery Tasks (MANDATORY):**
- [ ] T001 [P0] Run `etoro-service-api-discovery` MCP for all required internal APIs
- [ ] T002 [P0] Document discovered API contracts in `/specs/[feature]/contracts/`
- [ ] T003 [P0] Run infra NuGets MCP for required packages:
  - [ ] `monitoring` - Review ExecuteActionAsync patterns
  - [ ] `logging` - Review structured logging setup
  - [ ] `ccm` - Review configuration management
  - [ ] `rest-providers` - Review provider base classes (if REST integration needed)
  - [ ] [Add others based on requirements]
<!-- TEAM-SPECIFIC: END -->

---

## Phase 1: Interfaces / Contracts

**Purpose**: Define all interfaces and DTOs before implementation

**Constitution Check:**
- [ ] All interfaces defined in correct layer
- [ ] DTOs are immutable where appropriate
- [ ] Error schemas defined

### Interface Definitions

- [ ] T011 [P1] Create service interfaces in `dor-cytech-poc1.Application/Services/Interfaces/`
  - `Idor-cytech-poc1Service.cs`
  - [Add specific interfaces]
- [ ] T012 [P1] Create provider interfaces in `dor-cytech-poc1.Infrastructure/Providers/Interfaces/`
  - `I{ApiName}ApiProvider.cs` for each external dependency (e.g., `IInventoryApiProvider.cs`, NOT `IInventoryServiceProvider.cs`)
  - [Add specific interfaces]
- [ ] T013 [P1] Create repository interfaces (if data storage needed)
  - `dor-cytech-poc1.Infrastructure/Repositories/Interfaces/`

### DTO Definitions

- [ ] T014 [P] [P1] Create request/response DTOs in `dor-cytech-poc1.Api/Dto/`
- [ ] T015 [P] [P1] Create parameter DTOs in `dor-cytech-poc1.Application/Dto/Parameters/`
- [ ] T016 [P] [P1] Create result DTOs in `dor-cytech-poc1.Application/Dto/Results/`
- [ ] T017 [P] [P1] Create provider DTOs in `dor-cytech-poc1.Infrastructure/Dto/`

### Build Verification

- [ ] T018 [P1] Run `dotnet build` - MUST pass
- [ ] T019 [P1] Verify no circular dependencies

---

## Phase 2: Domain Layer

**Purpose**: Pure domain logic with no external dependencies

**Constitution Check:**
- [ ] No infrastructure NuGets referenced
- [ ] No external dependencies
- [ ] Pure entities and value objects

### Domain Implementation

- [ ] T020 [P] [P2] Create enumerations in `dor-cytech-poc1.Domain/Enumerations/`
- [ ] T021 [P] [P2] Create constants in `dor-cytech-poc1.Domain/Constants/`
- [ ] T022 [P] [P2] Create shared data objects in `dor-cytech-poc1.Application/Dto/Data/` (if needed — Domain is for Enumerations ONLY)

### Build Verification

- [ ] T023 [P2] Run `dotnet build` - MUST pass
- [ ] T024 [P2] Verify Domain project has no external infrastructure references

---

## Phase 3: Infrastructure Layer

**Agent**: infra-developer

**Purpose**: External integrations, providers, repositories

**Constitution Check:**
- [ ] All providers implement interfaces from Phase 1
- [ ] External dependencies have timeout/retry/backoff via Polly
- [ ] Health checks implemented for each external dependency
- [ ] Mock providers created for component tests

### Provider Implementation

- [ ] T025 [P3] Create configuration provider in `dor-cytech-poc1.Infrastructure/Providers/Concrete/`
  - `ConfigurationProvider.cs`
  - `IConfigurationProvider.cs` interface
  - **Add default value properties to IFeature interface (NO separate interface)**
    - `DefaultTransactionsItemsPerPage`, `MaxTransactionsItemsPerPage`, `MinTransactionsItemsPerPage` properties
    - CCM keys: `Feature_DefaultTransactionsItemsPerPage`, `Feature_MaxTransactionsItemsPerPage`, `Feature_MinTransactionsItemsPerPage`
- [ ] T026 [P3] Create REST provider base (if needed) in `dor-cytech-poc1.Infrastructure/Providers/Abstract/`
- [ ] T027 [P] [P3] Implement external API providers:
  - `{ApiName}ApiProvider.cs` for each discovered API (e.g., `InventoryApiProvider.cs`, NOT `InventoryServiceProvider.cs`)
  - Include Polly retry policies
  - Add structured logging
- [ ] T028 [P3] Create exception types in `dor-cytech-poc1.Infrastructure/Exceptions/`

### Test Infrastructure

- [ ] T029 [P] [P3] Create mock providers in `dor-cytech-poc1.Tests.Common.Infrastructure/Providers/`
  - One mock per external provider
- [ ] T030 [P3] Create test helpers in `dor-cytech-poc1.Tests.Common.Infrastructure/Helpers/`

### Build & Test Verification

- [ ] T031 [P3] Run `dotnet build` - MUST pass
- [ ] T032 [P3] Verify all providers have corresponding interfaces

---

## Phase 4: Application Layer (Business Logic)

**Agent**: app-developer

**Purpose**: Business logic with MonitorWrapper on all public async methods

**Constitution Check:**
- [ ] Every public async method wrapped with MonitorWrapper.ExecuteActionAsync
- [ ] Class size < 200 lines
- [ ] Services implement interfaces from Phase 1
- [ ] No direct infrastructure usage (use injected providers)

### Service Implementation

<!-- TEAM-SPECIFIC: START - Replace code examples below with your team's monitoring library patterns -->
- [ ] T033 [P4] Create service implementations in `dor-cytech-poc1.Application/Services/Concrete/`
  - Include MonitorWrapper constructor pattern (IMonitor MUST be LAST parameter):
    ```csharp
    private readonly IMonitorWrapper _monitorWrapper;  // ✅ NOT IMonitor _monitor
    
    public MyService(
        IProvider provider, 
        IConfigurationProvider configurationProvider,
        IMonitor monitor)  // ✅ IMonitor is ALWAYS the LAST parameter
    {
        _provider = provider;
        _configurationProvider = configurationProvider;
        _monitorWrapper = new MonitorWrapper(monitor, ComponentType.Service, nameof(MyService));
    }
    ```
- [ ] T034 [P4] Ensure all async methods use:
    ```csharp
    return await _monitorWrapper.ExecuteActionAsync(async () =>
    {
        // Business logic
    }, new { Parameters = parameters }, catchExceptions: false);
    ```
<!-- TEAM-SPECIFIC: END -->
- [ ] T035 [P] [P4] Create exception types in `dor-cytech-poc1.Application/Exceptions/`
- [ ] T036 [P] [P4] Create helpers in `dor-cytech-poc1.Application/Helpers/` (if needed)
- [ ] T037 [P] [P4] Create builders in `dor-cytech-poc1.Application/Builders/` (if needed)

### Health Checks

- [ ] T038 [P4] Create health check providers in `dor-cytech-poc1.Application/Health/`
  - One health check per external dependency

### Jobs (if needed)

- [ ] T039 [P4] Create background jobs in `dor-cytech-poc1.Application/Jobs/`
  - Job interfaces and implementations

### Build Verification

- [ ] T040 [P4] Run `dotnet build` - MUST pass
- [ ] T041 [P4] Verify MonitorWrapper usage on all public async methods
- [ ] T042 [P4] Verify class sizes < 200 lines

---

## Phase 5: Api Layer

**Agent**: api-developer

**Purpose**: Controllers, DI bootstrap

**Constitution Check:**
- [ ] Thin controllers (delegate to services)
- [ ] **Controller Method Pattern (Section XI)**: Single request object per method, NO `[FromQuery]`/`[FromRoute]`/`[FromBody]` on method parameters
- [ ] DI wires all layers correctly
- [ ] Health endpoints exposed
- [ ] CCM configuration loaded

### Bootstrap

- [ ] T043 [P5] Create `dor-cytech-poc1.Api/Bootstrap/Program.cs`
- [ ] T044 [P5] Create `dor-cytech-poc1.Api/Bootstrap/Startup.cs` with:
  - CCM configuration
  - MVC monitoring setup
  - DI registration for all services/providers
  - Health endpoint configuration
- [ ] T044b [P5] Wire optional Bootstrapper dependencies needed by this service:
  - Read `.cursor/skills/team/bootstrapper/SKILL.md` to get copy-paste patterns
  - Override only the deps your service actually uses (STS, ServiceBus, EventHubs, Cosmos, Redis, InMemory)
  - Add required `IConfigurationProvider` sections and CCM keys for each added dep
- [ ] T045 [P5] Configure `appsettings.json` with CCM KeyVault/Etcd

### DTO Validation Infrastructure (MUST follow Constitution Section XI)

- [ ] T046a [P] [P5] Create `ErrorCode.cs` enum in `dor-cytech-poc1.Api/Enumerations/`
  - Define all validation error codes (IdMustBePositive, ResourceIdRequired, etc.)
- [ ] T046b [P] [P5] Create `ErrorMessageConsts.cs` in `dor-cytech-poc1.Api/Constants/`
  - Define format strings: FieldIsRequiredFormat, FieldMustBePositiveFormat, etc.
- [ ] T046c [P] [P5] Create `RequestValidationException.cs` in `dor-cytech-poc1.Api/Exceptions/`
  - Extends `MonitorHandledException`, takes ErrorCode enum

### Request DTOs (MUST follow Constitution Section XI)

- [ ] T047 [P] [P5] Create request DTOs in `dor-cytech-poc1.Api/Dto/Requests/`
  - Each request class has `[FromRoute]`/`[FromQuery]`/`[FromBody]` on **properties** (NOT method params)
  - Each request class has `Validate()` method that throws `RequestValidationException`
  - Use `ErrorMessageConsts` format strings with `string.Format()`
  - Use `nameof(PropertyName)` for refactoring safety
  - **NO hardcoded defaults** (e.g., `= 10`) - defaults MUST come from ConfigurationProvider
  - `Validate()` method ONLY throws exceptions - do NOT reset values to defaults
  - Create `Body/` subfolder for POST/PUT request bodies
- [ ] T048 [P5] Create response DTOs in `dor-cytech-poc1.Api/Dto/Responses/`
- [ ] T049 [P] [P5] Create `RequestExtensions.cs` in `dor-cytech-poc1.Api/Extensions/`
  - `Internalize()` methods to convert request to application parameters
- [ ] T050 [P] [P5] Create `ResultExtensions.cs` in `dor-cytech-poc1.Api/Extensions/`
  - `Externalize()` methods to convert result to response

### Controllers (MUST follow Constitution Section XI)

- [ ] T051 [P] [P5] Create controllers in `dor-cytech-poc1.Api/Controllers/`
  - **SINGLE request object parameter per method** (e.g., `Get{Feature}Request request`)
  - **NO** `[FromQuery]`, `[FromRoute]`, `[FromBody]` on method parameters
  - First line: `request.Validate();`
  - Convert: `var parameters = request.Internalize();`
  - Return: `Ok(result.Externalize());`
  - Keep thin - delegate to Application services

### Build & Run Verification

- [ ] T050 [P5] Run `dotnet build` - MUST pass
- [ ] T051 [P5] Run `dotnet run` - Verify API starts
- [ ] T052 [P5] Verify health endpoints respond:
  - `GET /api/healthcheck`
  - `GET /api/status`
  - `GET /api/ping`
  - `GET /api/readiness`
  - `GET /api/liveness`

---

## Phase 6: Testing

**Agent**: test-developer

**Purpose**: Component and System tests following kyc-facade-api patterns

**Constitution Check:**
- [ ] Uses NUnit (no other frameworks)
- [ ] Component tests mock all external providers
- [ ] System tests have per-environment appsettings
- [ ] Test categories: `[Category("ComponentTests")]`, `[Category("SystemTests")]`

### Test Common Projects

- [ ] T053 [P] [P6] Create test DTOs in `dor-cytech-poc1.Tests.Common.Domain/Dto/`
- [ ] T054 [P] [P6] Create test enumerations in `dor-cytech-poc1.Tests.Common.Domain/Enumerations/`

### Component Tests

- [ ] T055 [P6] Create `dor-cytech-poc1.Tests.Component/Bootstrap/Startup.cs`
- [ ] T056 [P6] Create `dor-cytech-poc1.Tests.Component/Bootstrap/ComponentTestBootstrapper.cs`
- [ ] T057 [P6] Create `dor-cytech-poc1.Tests.Component/Tests/Abstract/TestsBase.cs` (NOT TestBase)
  - Extend `ComponentTestBase<Startup>`
  - Setup mock providers via `GetServiceMock<T>()`
  - `[OneTimeSetUp] public void Init()` and `[SetUp] public new void SetUp()`
- [ ] T058 [P6] Create constants in `dor-cytech-poc1.Tests.Component/Constants/`
- [ ] T059 [P] [P6] Create component tests in `dor-cytech-poc1.Tests.Component/Tests/`
  - Test each API endpoint
  - Test success and failure scenarios
  - Use `[TestFixture]` and `[Category("ComponentTests")]`

### System Tests (WRITE ONLY - DO NOT RUN)

**⚠️ IMPORTANT**: System tests MUST be written but MUST NOT be executed locally. CI/CD pipelines handle system test execution.

- [ ] T060 [P6] Create `dor-cytech-poc1.Tests.System/Bootstrap/SystemTestBootstrapper.cs`
  - Extend `SystemTestBase<Bootstrapper, IConfigProvider, ConfigProvider>`
- [ ] T061 [P] [P6] Create appsettings files **(see skill: team/system-testing for appsettings pattern)**:
  - `appsettings.local.json` - CCM config + Etcd bootstrap values ONLY (no application config!)
  - `appsettings.integration.json` - KeyVault + Etcd CCM config ONLY
  - `appsettings.staging.json` - KeyVault + Etcd CCM config ONLY
  - `appsettings.production.json` - KeyVault + Etcd CCM config ONLY
  - ❌ **DO NOT** add application-specific config (API URLs, GCIDs, test data) in appsettings - use CCM!
- [ ] T062 [P6] Create system test configuration provider in `dor-cytech-poc1.Tests.System.Infrastructure/Providers/`
- [ ] T063 [P] [P6] Create system tests in `dor-cytech-poc1.Tests.System/Tests/`
  - Test real API endpoints
  - Use `[TestFixture]` and `[Category("SystemTests")]`
  - ❌ DO NOT run these tests locally - write them only

### Test Execution

- [ ] T064 [P6] Run `dotnet test --filter Category=ComponentTests` - ALL MUST PASS
- [ ] T065 [P6] ~~Run system tests~~ **System tests are written but NOT run locally** (CI/CD handles execution)

---

## Phase 7: Polish & Quality Gates

**Purpose**: Final cleanup and gate verification

### Quality Gates

- [ ] T066 Run full build: `dotnet build`
- [ ] T067 Run all component tests: `dotnet test --filter Category=ComponentTests`
- [ ] T068 ~~Run system tests~~ **Verify system tests are written** (DO NOT run - CI/CD handles execution)
- [ ] T069 Perform call redundancy audit:
  - Identify redundant network calls
  - Identify repeated computations
  - Confirm no duplicated side effects
- [ ] T070 Review and clean up logs:
  - Remove debug logs not needed in production
  - Verify structured logging format
  - Ensure no sensitive data logged
- [ ] T071 Verify MonitorWrapper coverage on all public async methods
- [ ] T072 Verify class sizes < 200 lines
- [ ] T073 Review exception handling consistency

### Template Cleanup (REQUIRED)

Example files already live in `.reference/` — no file moving needed. This phase handles test provider renaming, unused NuGet removal, and unused code cleanup.

- [ ] T075 Remove unused NuGet packages from csproj files (ServiceBus, Cosmos, EventHubs, Microsoft.Data.SqlClient, Caching.InMemory, Caching.Redis — remove if not needed by the feature)
- [ ] T076 Verify `dotnet build` passes after cleanup
- [ ] T077 Verify `dotnet test --filter Category=ComponentTests` passes after cleanup

### Unused Code Cleanup (REQUIRED)

⚠️ **DO NOT DELETE** `IHealthcheckCommand` / `IStatusCommand` / `IReadinessCommand` implementations — they are discovered and registered via DI reflection by the Monitor framework, so they appear unreferenced in code but ARE used at runtime.

- [ ] T081a Scan all projects for classes that are defined but never referenced (unused DTOs, unused services, unused interfaces, unused helpers). Delete them.
- [ ] T081b Remove unused `using` statements from all `.cs` files across all projects.
- [ ] T081c Verify `dotnet build` passes after unused code cleanup.
- [ ] T081d Verify `dotnet test --filter Category=ComponentTests` passes after unused code cleanup.

### README Documentation (Constitution Section XIV - MANDATORY)

- [ ] T081 [P7] Generate comprehensive `README.md` following Constitution Section XIV structure:
  - [ ] T081a Scan `Bootstrapper.cs` for all registered providers → populate External Dependencies table
  - [ ] T081b Scan all controllers for route attributes → populate API Endpoints table
  - [ ] T081c Scan `IConfigurationProvider.cs` and `ConfigurationProvider.cs` → populate CCM Keys table
  - [ ] T081d Scan all DTOs across all layers for `[SensitiveData]` attributes → populate PII Inventory table
  - [ ] T081e Document all secrets/tokens with source, CCM key, code path, and rotation policy
  - [ ] T081f Cross-reference PII inventory with `Monitoring_SensitiveProperties` CCM configuration
  - [ ] T081g Verify README completeness: every provider, endpoint, CCM key, and PII field in code is documented
- [ ] T082 Document any deviations from constitution

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 0 (Planning)**: No dependencies - MUST complete first
- **Phase 1 (Interfaces)**: Depends on Phase 0
- **Phase 2 (Domain)**: Depends on Phase 1
- **Phase 3 (Infrastructure)**: Depends on Phase 1, Phase 2
- **Phase 4 (Application)**: Depends on Phase 1, Phase 2, Phase 3
- **Phase 5 (Api)**: Depends on Phase 4
- **Phase 6 (Testing)**: Depends on Phase 5
- **Phase 7 (Polish)**: Depends on Phase 6

### Parallel Opportunities

Tasks marked [P] within a phase can run in parallel.

---

## Gate Checklist (Must Pass Each Phase)

- [ ] Build passes (`dotnet build`)
- [ ] Component tests pass (`dotnet test --filter Category=ComponentTests`)
- [ ] System tests written (DO NOT run - CI/CD only)
- [ ] No circular dependencies
- [ ] MonitorWrapper on all public async methods (Phase 4+)
- [ ] Class sizes < 200 lines
- [ ] Logging cleaned and production-ready

---

## Notes

- [P] tasks = different files, no dependencies within phase
- [Phase] label maps task to specific phase for constitution compliance
- Each phase MUST pass its gate before proceeding
- Verify tests fail before implementing (where applicable)
- Commit after each task or logical group
- NEVER skip tests or quality gates
