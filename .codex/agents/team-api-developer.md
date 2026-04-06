---
name: "api-developer"
description: "Trading API layer: sealed controllers, [AuthorizeLevel], FluentValidation, AutoMapper, API versioning, AppSecret/STS auth."
---

<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/agents/team/api-developer.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->
<!-- TEAM-SPECIFIC: This agent extends core/api-developer.md with eToro Trading NuGet patterns. Replace with your team's library-specific agent. -->

# API Developer — Trading NuGets

**FIRST read**: `.codex/agents/core-api-developer.md` for architecture standards.

Then read these team skills for Trading-specific code examples:
1. `.codex/skills/team-api-controllers/SKILL.md` — Trading controller patterns, [AuthorizeLevel], FluentValidation, AutoMapper
2. `.codex/skills/team-monitoring-logging/SKILL.md` — Framework.Log, ITicksTrail, structured logging

## Reference Files

**IMPORTANT**: Only read reference files relevant to your task. Skip groups that don't apply.

> **Real code first**: If the project already has implemented code for a pattern (e.g., an existing controller or middleware), read it and follow its conventions for consistency. Real project code takes priority over `.reference/` examples.

> **Discovery**: `dor-cytech-poc1` is a placeholder. Discover actual project names by scanning `*.csproj` files in the repository root.

### ALWAYS read — Controller + auth pipeline (in `.reference/`)
- `.reference/Api/Controllers/ExampleController.cs` — Full controller: [AuthorizeLevel], FluentValidation, ApiResponse<T>
- `.reference/Api/Authorization/AuthorizeLevelAttribute.cs` — Custom [AuthorizeLevel] attribute implementation

### Read if feature needs AppSecret auth details
- `.codex/skills/team-api-controllers/references/auth-patterns.md` — Full AppSecret + STS implementation code

### Read if feature needs Swagger
- `.codex/skills/team-api-controllers/references/swagger-openapi.md` — Swagger configuration and documentation requirements

### Read if feature needs API standards compliance
- `.codex/skills/team-api-controllers/references/api-standards.md` — Per-tier compliance checklist

## Trading-Specific Constraints
- Controllers MUST be `sealed` with `[ApiController]` and `[Produces("application/json")]`
- Route pattern: `api/v{version:apiVersion}/{resource}` with `[ApiVersion(1)]`
- DO NOT use `[controller]` token in routes
- `[AuthorizeLevel(AuthorizationLevel.ReadOnly)]` for GET, `[AuthorizeLevel(AuthorizationLevel.ReadWrite)]` for mutations
- `[ValidateUserIdentifier]` on controllers requiring user tracking
- FluentValidation for request validation via `APIRequestValidationService.RequestIsValid<T>()`
- AutoMapper for entity-to-DTO mapping
- `ApiResponse<T>` envelope with `RequestGuid`, `Success`, `Message`, `Data`
