# Service Constitution — Core Standards
<!-- DO NOT MODIFY: This file contains general architecture standards that apply regardless of which NuGet libraries your team uses. For library-specific rules, see constitution-team.md -->
<!-- Version: 1.0.0 | Split from constitution.md v3.1.0 -->

## Multi-Agent Architecture

This constitution is the **core rules document** — always loaded in context. For library-specific HOW rules, see `constitution-team.md` in this same directory. Detailed implementation patterns live in skills, subagents, and rules:

| Layer | Location | When Active | Purpose |
|-------|----------|-------------|---------|
| **Constitution** (this file) | `.specify/memory/constitution.md` | Always | WHAT rules, WHY they matter |
| **Constitution Team** | `.specify/memory/constitution-team.md` | Always | Library-specific HOW rules |
| **Core Subagents** | `.cursor/agents/core/` | Delegated during implementation | WHO — architecture standards (DO NOT MODIFY) |
| **Team Subagents** | `.cursor/agents/team/` | Delegated during implementation | WHO — library-specific execution (CUSTOMIZE) |
| **Rules** | IDE rules directory | Auto-applied by IDE when editing matching files | WHO for ad-hoc work on matching files |
| **Core Skills** | `.cursor/skills/core/` | On demand | HOW — architecture patterns (DO NOT MODIFY) |
| **Team Skills** | `.cursor/skills/team/` | On demand | HOW — library-specific code (CUSTOMIZE) |

---

## Placeholder Pattern Reference

| Placeholder | Description | Example Value |
|-------------|-------------|---------------|
| `dor-cytech-poc1` | Solution/project namespace prefix | `Order.Management` |
| `{ServiceName}` | Service name for display/config | `Order Management Api` |
| `{service-name}` | Kebab-case service name | `order-management-api` |
| `{Feature}` | Feature/domain name | `Checkout`, `Profile` |
| `{Resource}` | REST resource name (plural) | `Orders`, `Users` |
| `{ApiName}` | External API name (PascalCase) | `Payment`, `Inventory` |
| `{apiName}` | External API name (camelCase) | `payment`, `inventory` |
| `{Action}` | CRUD action name | `Get`, `Create`, `Update` |

---


## Core Principles

### I. Plan Before Code (NON-NEGOTIABLE)

Do NOT start implementation until the project plan (FR/NFR, architecture, test strategy) is approved.

Every feature MUST produce: FR/NFR specification, architecture plan with layer breakdown, testing plan (Component + System), and pass all planning gates before Phase 1.

**Spec directory**: `specs/[###-feature-name]/` at project root. `.specify/` is reserved for constitution, templates, scripts.

---

### II. Bottom-Up Layering Only (NON-NEGOTIABLE)

Implementation order: **Interfaces/Contracts → Domain → Infrastructure → Application → Api**

**Layer dependency rules:**
- **Domain**: Enumerations ONLY. No DTOs, no external dependencies.
- **Application**: References Domain. Contains `Dto/Parameters/`, `Dto/Results/`, `Dto/Data/`, service interfaces.
- **Infrastructure**: References Domain. Implements provider interfaces. Contains provider-specific DTOs.
- **Api**: References Application and Infrastructure (composition root). Contains request/response DTOs.

**DTO locations:**

| DTO Type | Location |
|----------|----------|
| Service input | `Application/Dto/Parameters/` |
| Service output | `Application/Dto/Results/` |
| Shared data objects | `Application/Dto/Data/` |
| API request/response | `Api/Dto/Requests/`, `Api/Dto/Responses/` |
| Provider request/response | `Infrastructure/Providers/Dto/Requests/{ApiName}/`, `Responses/{ApiName}/` |
| Repository parameters/results | `Infrastructure/Repositories/Dto/Parameters/`, `Dto/Results/` |
| Repository documents | `Infrastructure/Repositories/Dto/Documents/` |
| Enumerations | `Domain/Enumerations/` |
| Action filters | `Api/ActionFilters/Admin/` |
| API exceptions | `Api/Exceptions/` |

**CRITICAL DTO naming**: NO "Provider" in DTO names. Use `{Operation}Request` / `{Operation}Response`. Provider DTOs MUST be organized by API in subfolders. NO technology names (Mssql, Redis, Cosmos, Sql) in Parameters/Result/DTO class names — name by **feature/domain**, not by storage technology.

**Infrastructure file locations:**

| Component | Location |
|-----------|----------|
| Provider interfaces | `Infrastructure/Providers/Interfaces/` |
| Provider implementations | `Infrastructure/Providers/Concrete/` |
| Configuration provider | `Infrastructure/Providers/` (team-specific structure) |
| Provider base classes | `Infrastructure/Providers/Abstract/` |
| Provider exceptions | `Infrastructure/Providers/Exceptions/` |
| Provider DTOs | `Infrastructure/Providers/Dto/Requests/{ApiName}/`, `Dto/Responses/{ApiName}/` |
| Repository interfaces | `Infrastructure/Repositories/Interfaces/` |
| Repository implementations | `Infrastructure/Repositories/Concrete/` |
| Repository documents | `Infrastructure/Repositories/Dto/Documents/` |
| Repository parameters/results | `Infrastructure/Repositories/Dto/Parameters/`, `Dto/Results/` |
| Repository exceptions | `Infrastructure/Repositories/Exceptions/` |

> See core skill: `config-management` for configuration principles, `rest-providers` for provider patterns, `data-repositories` for repository patterns.

---

#### No Hardcoded Secrets (NON-NEGOTIABLE)

All secrets in a secret vault, non-sensitive config in distributed config, accessed via a dedicated configuration provider.

#### Configuration Provider Pattern (NON-NEGOTIABLE)

Every service MUST have a typed configuration provider that centralizes all config access. The specific pattern (single nested class vs typed config classes) is team-specific — see `constitution-team.md` and team skill `config-ccm` for your team's implementation.

> See core skill: `config-management` for configuration principles, team skill `config-ccm` for team-specific patterns.

#### Repository Method Signatures (NON-NEGOTIABLE)

Repository methods MUST accept a single Parameters class and return a Result class — NOT multiple primitive parameters.

- Input: `{Action}{Feature}Parameters` (e.g., `CreateAlertParameters`, `GetAlertsByUserParameters`)
- Output: `{Action}{Feature}Result` or domain class (e.g., `CreateAlertResult`, `AlertData`)
- Parameters classes in `Infrastructure/Repositories/Dto/Parameters/`
- Result classes in `Infrastructure/Repositories/Dto/Results/`
- **FORBIDDEN**: `CreateAlertAsync(long userId, int instrumentId, decimal targetPrice, int direction)` — use `CreateAlertAsync(CreateAlertParameters parameters)` instead

> See core skill: `data-repositories` for repository patterns.

#### Class Member Ordering (NON-NEGOTIABLE)

Constants → static fields → instance fields → constructor(s) → public properties → public methods → protected → private. ALL public before ALL private.

#### Dictionary Naming: `{Key}To{Value}` pattern (e.g., `SymbolToCatalogItem`).

#### Ternary formatting: Multi-line when exceeding ~80 chars with `?` and `:` on separate lines.

---

### III. Quality Gates After Every Step (NON-NEGOTIABLE)

Each phase MUST end with: `dotnet build` passes, `dotnet test --filter "Category=ComponentTests"` passes, call redundancy audit, logging cleaned, phase report documented.

**DO NOT** run system tests for gate verification.

---

### IV. Testing Is Mandatory (NON-NEGOTIABLE)

**Required test projects**: Tests.Common.Domain, Tests.Common.Infrastructure, Tests.Component (RUN locally), Tests.System (WRITE only — DO NOT run locally), Tests.System.Domain, Tests.System.Infrastructure.

**Test class naming**: `{Feature}Tests` (NOT `ControllerTests`). Test base: `TestsBase` (NOT `TestBase`).

**Test API provider**: MUST use dedicated `dor-cytech-poc1ApiProvider` inheriting a REST provider base class. Direct `HttpClient` usage in tests is FORBIDDEN.

**Component test execution**: `dotnet test --filter "Category=ComponentTests"` only. NEVER run system tests locally.

> See core skills: `component-testing` for component test architecture, `system-testing` for system test patterns.

---

### V. Monitoring Discipline (NON-NEGOTIABLE)

Every async method in Application services MUST be wrapped with a monitoring wrapper. The raw monitor dependency MUST be the LAST constructor parameter. Store as a wrapper abstraction (NOT the raw monitor interface).

> See core skill: `monitoring-logging` for monitoring patterns.

---

### VI. External Dependencies Verification (NON-NEGOTIABLE)

For EVERY external call: define contract, auth, timeout/retry/backoff, mock, verification tests, observability.

**Resilience**: All REST providers MUST implement circuit breaker / retry / timeout patterns. The specific implementation (provider base class, Polly pipeline, etc.) is team-specific — see team skill `rest-provider`.

**Registration**: Providers MUST be registered using your team's prescribed pattern. See team skill `rest-provider`.

**Provider SRP**: Single API calls only. Pagination/aggregation in Application layer.

**Provider naming**: `I{ApiName}ApiProvider` / `{ApiName}ApiProvider`.

**Handled exception pattern**: Controllers MUST NOT return status results directly. Throw custom exceptions that map to HTTP status codes. Unhandled exceptions automatically return 500.

> See core skill: `rest-providers` for provider patterns.

---

### VII. Logging Discipline (NON-NEGOTIABLE)

- Never log sensitive data — use sensitive data annotations
- **PII → `Mask`**, **Secrets → `Hash`**. No exceptions.
- Structured logging, no string interpolation in log message templates

> See core skill: `monitoring-logging` for sensitive data classification table and patterns.

---

### VIII. Class Size Limits

Maximum ~200 lines per class. One responsibility per class. Prefer composition over inheritance.

---

### IX. Type Preferences (NON-NEGOTIABLE)

MUST prefer `class` over `record` for all DTOs, entities, data models. `record` only when immutability + value equality explicitly justified.

---

### X. API Design & Route Convention (NON-NEGOTIABLE)

- Routes: `api/v1/{resource}` — lowercase, kebab-case, plural nouns
- Client-facing auth attribute on every client-facing controller action
- Backend auth filter on every backend-to-backend controller action
- User identity NEVER in routes for client-facing endpoints — always from auth validation result
- Backend-to-backend endpoints MAY have user identity in route/query (caller is a service)
- No `[controller]` token in route attributes
- Versioning: URL-based (`v1`, `v2`), integer only
- Query params: camelCase
- Pagination: `hasNext` ALWAYS required. Cursor-based recommended for large datasets.
- Distributed tracing: `X-Request-Id`, `X-Correlation-Id`

> See core skill: `api-design` for full REST conventions, pagination, caching, versioning patterns.

---

### XI. Controller Method Pattern (NON-NEGOTIABLE)

Single request object per action. Flow: validate request → map to parameters → service call → map to response → return.

- Binding attributes on DTO properties (NOT method parameters)
- Request validation MUST happen before service call. The validation approach (manual `Validate()`, FluentValidation, etc.) is team-specific — see team skill `api-controllers`.
- Request defaults from configuration (NOT hardcoded)
- Parameterless GET endpoints: no request DTO, create parameters directly

> See core skill: `api-controllers` for complete controller, DTO, and extension method patterns.

---

### XII. Swagger/API Documentation (NON-NEGOTIABLE)

OpenAPI 3.0+. Business perspective descriptions. XML docs on ALL public types.

Required: `[ProducesResponseType]` for every status code, `/// <summary>`, `/// <remarks>`, `/// <response code>`, `/// <example>` on all properties.

> See core skill: `swagger-docs` for documentation requirements and patterns.

---

### XIII. Constitution Compliance Guardrails (NON-NEGOTIABLE)

When a developer requests a violation:
1. **Stop and notify** — cite the violated principle
2. **Explain correct approach**
3. **Request explicit confirmation**

If proceeding despite violation, add inline `// ⚠️ CONSTITUTION VIOLATION:` comment.

**Always blocked**: Hardcoding secrets, bypassing auth, force-pushing to main, skipping all tests.

---

### XIV. Security Review Gate (NON-NEGOTIABLE)

Every service MUST pass the Security Agent review after plan completion and before task generation. The review evaluates data classification, cluster placement, authentication, PII handling, dependency sensitivity, and service type against the Security Agent MVP Ruleset. The plan.md MUST include a **Service Security Profile** section with mandatory declarations — this is the primary input for security validation before any code exists.

- **Auto-approved** services proceed to implementation
- **Auto-rejected** services MUST resolve all violations before proceeding
- **Manual-review** services require security architect sign-off

The Cytech agent GitHub Action enforces the same rules on PR, blocking merge for Auto-reject verdicts.

> See core skill: `security-review` for the complete ruleset. See core skill: `cluster-deployment` for cluster placement validation.

---

### XV. README Documentation (NON-NEGOTIABLE)

README generated in Phase 7 from actual code. MUST include: Service Overview, Architecture, API Endpoints, External Dependencies, Configuration Keys, **Sensitive Data & PII Inventory** (MANDATORY), Health/Monitoring, Development, Testing, Deployment.

> See core skill: `readme-generation` for full README structure and generation process.

---

## Project Structure (EXISTING TEMPLATE)

**DO NOT** create new `.sln`, `.csproj`, or run `dotnet new`. Only add/modify `.cs` files, package references, config files.

The template repo IS the reference implementation. Read actual template files for patterns.

---

## Naming Convention Summary

| Component | Pattern | Example |
|-----------|---------|---------|
| Solution | `dor-cytech-poc1.Api.sln` | `Order.Management.Api.sln` |
| Controller | `{Resource}Controller` (plural) | `OrdersController` |
| Service Interface | `I{Feature}Service` | `ICheckoutAggregatorService` |
| Provider Interface | `I{ApiName}ApiProvider` | `IPaymentApiProvider` |
| Test Class | `{Feature}Tests` | `CheckoutTests` |
| Request DTO | `{Action}{Feature}Request` | `GetCheckoutDetailRequest` |
| Response DTO | `{Feature}Response` | `CheckoutDetailResponse` |
| Parameters | `{Action}{Feature}Parameters` | `GetCheckoutDetailParameters` |
| Result | `{Action}{Feature}Result` | `GetCheckoutDetailResult` |
| Provider DTO | `{Operation}Request/Response` | `GetOrdersRequest` (NO "Provider") |
| Repository Parameters | `{Action}{Feature}Parameters` | `CreateAlertParameters` |
| Repository Result | `{Action}{Feature}Result` | `CreateAlertResult` |
| Dictionary Property | `{Key}To{Value}` | `SymbolToCatalogItem` |

---

## Anti-patterns (DO NOT DO)

- Skipping tests "for speed"
- Building Api before Infrastructure/Application stable
- External calls without auth+contract+tests
- Adding logs and never cleaning them
- Classes exceeding ~200 lines
- `record` instead of `class` for DTOs
- Non-versioned routes (MUST be `api/v1/{resource}`)
- `[controller]` token in route attributes
- Multiple parameters on controller methods
- Binding attributes (`[FromQuery]`/`[FromRoute]`/`[FromBody]`) on method parameters (put on DTO properties)
- Hardcoded string comparisons for enum validation (use `Enum.TryParse` + `Enum.IsDefined`)
- Missing request validation in controller methods
- User identity in routes for client-facing endpoints
- Missing auth attributes on protected actions
- Separate providers per method to same API
- Creating new `.sln`/`.csproj` files
- `ServiceProvider` suffix on REST providers (use `ApiProvider`)
- snake_case query parameters (use camelCase)
- Pagination metadata in headers (put in response body)
- Enum IDs without enumeration endpoint
- Verbs in API URLs
- Breaking changes without version bump
- Feature flags for breaking/security changes
- API deprecation without `Sunset` header (RFC 8594)
- Implementation-perspective documentation (use business perspective)
- Non-UTC date formats
- Missing error response documentation
- Missing `hasNext` in pagination
- Stub/placeholder implementations
- AI silently implementing constitution violations
- Missing README or missing PII inventory section
- Hardcoding secrets in code or config files
- Technology names in DTO/Parameters/Result class names
- Multiple primitive parameters on repository methods — use a single Parameters class
- Including unused fields in provider response DTOs — only include properties your service actually accesses
- Non-happy-flow tests in system tests — those belong in component tests
- Constructing application Parameters objects inline in controllers — use mapping extension methods
- Using `async`/async wrapper on methods with NO `await` — use the sync variant instead

---

## Governance

- This constitution supersedes all other practices
- Amendments require documentation, approval, and migration plan
- All PRs/reviews MUST verify compliance
- Complexity MUST be justified

**Version**: 1.0.0 | **Split from**: constitution.md v3.1.0
