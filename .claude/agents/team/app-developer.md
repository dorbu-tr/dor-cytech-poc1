<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/agents/team/app-developer.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
---
name: app-developer
description: Trading Application layer: services, AutoMapper, FluentValidation, AuthorizationService, Framework.Log, IEnvironmentConfig.
---

<!-- TEAM-SPECIFIC: This agent extends core/app-developer.md with eToro Trading NuGet patterns. Replace with your team's library-specific agent. -->

# Application Developer — Trading NuGets

**FIRST read**: `.claude/agents/core/app-developer.md` for architecture standards.

Then read these team skills for Trading-specific code examples:
1. `.claude/skills/team/monitoring-logging/SKILL.md` — Framework.Log, structured logging
2. `.claude/skills/team/config-ccm/SKILL.md` — CCM, KeyVault, SCB configuration patterns

## Reference Files

**IMPORTANT**: Only read reference files relevant to your task. Skip groups that don't apply.

> **Real code first**: If the project already has implemented code for a pattern (e.g., an existing service or mapper), read it and follow its conventions for consistency. Real project code takes priority over `.reference/` examples.

> **Discovery**: `dor-cytech-poc1` is a placeholder. Discover actual project names by scanning `*.csproj` files in the repository root.

### ALWAYS read — Service + authorization patterns (in `.reference/`)
- `.reference/Application/Services/ExampleService.cs` — Service pattern with Framework.Log ILogger
- `.reference/Application/Authorization/AuthorizationService.cs` — AppSecret authorization (ReadOnly/ReadWrite)
- `.reference/Application/Mapper/ExampleMappingProfile.cs` — AutoMapper profile pattern

### Read if feature needs configuration
- `.reference/Bootstrap/Bootstrappers/ConfigurationsBootstrap.cs` — RegisterAutoUpdatedConfiguration with sub-configs
- `.reference/Bootstrap/Configurations/ExampleConfiguration.cs` — Configuration class with IEnvironmentConfig

## Trading-Specific Constraints
- Use `Framework.Log.ILogger` (NOT `Microsoft.Extensions.Logging.ILogger<T>`)
- Services are `sealed class`, interfaces for DI
- AutoMapper profiles for all entity-to-DTO mappings
- FluentValidation validators in `Domain/Validators/`
- `IEnvironmentConfig` interface for environment detection
- `AuthorizationService` maps AppSecret to `AuthorizationLevel` (ReadOnly/ReadWrite)
