<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/agents/team/infra-developer.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh copilot -->
---
description: "Trading Infrastructure layer: MSSQL BaseRepository, stored procedures, Polly resilience, Scrutor cached repositories, Trading.Infrastructure.Providers."
---

<!-- TEAM-SPECIFIC: This agent extends core/infra-developer.md with eToro Trading NuGet patterns. Replace with your team's library-specific agent. -->

# Infrastructure Developer — Trading NuGets

**FIRST read**: `.github/agents/core/infra-developer.md` for architecture standards.

Then read these team skills for Trading-specific code examples:
1. `.github/skills/team/config-ccm/SKILL.md` — CCM, KeyVault, SCB configuration patterns
2. `.github/skills/team/rest-provider/SKILL.md` — REST providers, Polly resilience, Framework.FaultTolerance
3. `.github/skills/team/monitoring-logging/SKILL.md` — Framework.Log, structured logging
4. `.github/skills/team/data-repositories/SKILL.md` — MSSQL BaseRepository, stored procedures, cached repositories

## Reference Files

**IMPORTANT**: Only read reference files relevant to your task. Skip groups that don't apply.

> **Real code first**: If the project already has implemented code for a pattern (e.g., an existing repository or provider), read it and follow its conventions for consistency. Real project code takes priority over `.reference/` examples.

> **Discovery**: `dor-cytech-poc1` is a placeholder. Discover actual project names by scanning `*.csproj` files in the repository root.

### ALWAYS read — Repository + Bootstrap patterns (in `.reference/`)
- `.reference/Infrastructure/Repositories/ExampleRepository.cs` — BaseRepository + stored procedure pattern
- `.reference/Infrastructure/Repositories/ExampleCachedRepository.cs` — Scrutor decorator caching pattern
- `.reference/Bootstrap/Bootstrappers/BasicBootstrap.cs` — DI registration pattern

### Read if feature needs database access
- `.github/skills/team/data-repositories/references/database-access.md` — Full BaseRepository, retry decorator, DbSelector

### Read if feature needs external APIs
- `.github/skills/team/rest-provider/references/nuget-packages.md` — Complete Trading NuGet package catalog

### Read if feature needs configuration
- `.reference/Bootstrap/Bootstrappers/ConfigurationsBootstrap.cs` — RegisterAutoUpdatedConfiguration
- `.reference/Bootstrap/Bootstrappers/HealthCheckBootstrap.cs` — Health check registration

## Trading-Specific Constraints
- MSSQL access via ADO.NET stored procedures (no Entity Framework, no Dapper)
- Repositories inherit from `BaseRepository`
- Naming: `Db{Feature}Repository` (not just `{Feature}Repository`)
- Cached repositories use Scrutor `Decorate<>()` pattern
- Polly `ResiliencePipeline` for retry/timeout/circuit breaker
- Connection strings from KeyVault (NOT appsettings.json)
- `shared.props` version variables for Trading NuGet packages
