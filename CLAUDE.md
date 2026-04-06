<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->

# dor-cytech-poc1

Clean Architecture .NET API service built with the eToro SDD template.

## Tech Stack

.NET 8, C#, Clean Architecture, NUnit, Shouldly

## Architecture Agents

Read the appropriate agent pair (core + team) based on the layer you are working in:

### api-developer
Implements API layer: controllers, request/response DTOs, validation, mapping extensions, Swagger documentation, route conventions.
- Core: `.claude/agents/core/api-developer.md`
- Team: `.claude/agents/team/api-developer.md`

### app-developer
Implements Application layer: services with monitoring wrapping, event publishing, application DTOs (Parameters/Results/Data), application exceptions.
- Core: `.claude/agents/core/app-developer.md`
- Team: `.claude/agents/team/app-developer.md`

### infra-developer
Implements Infrastructure layer: REST providers, configuration, circuit breaker, health commands, external API integrations, repositories, messaging, caching.
- Core: `.claude/agents/core/infra-developer.md`
- Team: `.claude/agents/team/infra-developer.md`

### test-developer
Implements Component and System tests: test bootstrapper, auth mocking, test API providers, assertions, infrastructure mocking.
- Core: `.claude/agents/core/test-developer.md`
- Team: `.claude/agents/team/test-developer.md`

## Skills Reference

### Core Skills

- **api-controllers** (`.claude/skills/core/api-controllers/SKILL.md`)
- **api-design** (`.claude/skills/core/api-design/SKILL.md`)
- **cluster-deployment** (`.claude/skills/core/cluster-deployment/SKILL.md`)
- **component-testing** (`.claude/skills/core/component-testing/SKILL.md`)
- **config-management** (`.claude/skills/core/config-management/SKILL.md`)
- **data-repositories** (`.claude/skills/core/data-repositories/SKILL.md`)
- **monitoring-logging** (`.claude/skills/core/monitoring-logging/SKILL.md`)
- **readme-generation** (`.claude/skills/core/readme-generation/SKILL.md`)
- **rest-providers** (`.claude/skills/core/rest-providers/SKILL.md`)
- **security-review** (`.claude/skills/core/security-review/SKILL.md`)
- **swagger-docs** (`.claude/skills/core/swagger-docs/SKILL.md`)
- **system-testing** (`.claude/skills/core/system-testing/SKILL.md`)

### Team Skills

- **api-controllers** (`.claude/skills/team/api-controllers/SKILL.md`)
- **component-testing** (`.claude/skills/team/component-testing/SKILL.md`)
- **config-ccm** (`.claude/skills/team/config-ccm/SKILL.md`)
- **data-repositories** (`.claude/skills/team/data-repositories/SKILL.md`)
- **monitoring-logging** (`.claude/skills/team/monitoring-logging/SKILL.md`)
- **orchestration** (`.claude/skills/team/orchestration/SKILL.md`)
- **rest-provider** (`.claude/skills/team/rest-provider/SKILL.md`)
- **system-testing** (`.claude/skills/team/system-testing/SKILL.md`)
- **worker-service** (`.claude/skills/team/worker-service/SKILL.md`)

## Key Conventions

### api-developer
API layer: controllers, DTOs, validation, Swagger, route conventions

<!-- CUSTOMIZE: Update team agent/skill paths to match your team's library implementations -->

# API Developer Context

You are editing the **API layer** of a .NET API service.

**Read the agent context (both files)**:
1. `.claude/agents/core/api-developer.md` (DO NOT MODIFY — architecture standards)
2. `.claude/agents/team/api-developer.md` (CUSTOMIZE — library-specific patterns)

**Quick constraints**: Single request object per action, routes `api/v1/{resource}`, binding attributes on DTO properties not method params, `Internalize()`/`Externalize()` extensions, `FromData()` on nested data items. Follow auth and validation patterns from team agent.

### infra-developer
Infrastructure layer: providers, repositories, config, messaging, caching, data access

<!-- CUSTOMIZE: Update team agent/skill paths to match your team's library implementations -->

# Infrastructure Developer Context

You are editing the **Infrastructure layer** of a .NET API service.

**Read the agent context (both files)**:
1. `.claude/agents/core/infra-developer.md` (DO NOT MODIFY — architecture standards)
2. `.claude/agents/team/infra-developer.md` (CUSTOMIZE — library-specific patterns)

**Quick constraints**: Dedicated registration method per provider, repos in `RegisterRepositories()`, providers in `RegisterProviders()`, jobs in `RegisterJobs()`, no hardcoded secrets. Follow configuration and provider patterns from team agent.

### test-developer
Tests: component tests, system tests, bootstrapper, auth mocking, infrastructure mocking

<!-- CUSTOMIZE: Update team agent/skill paths to match your team's library implementations -->

# Test Developer Context

You are editing **tests** for a .NET API service.

**Read the agent context (both files)**:
1. `.claude/agents/core/test-developer.md` (DO NOT MODIFY — architecture standards)
2. `.claude/agents/team/test-developer.md` (CUSTOMIZE — library-specific patterns)

**Quick constraints**: NUnit + Shouldly only, `TestsBase : ComponentTestBase<Startup>`, `GetServiceMock<T>()`, `.Reset()`, system tests write-only (never run locally), `dotnet test --filter "Category=ComponentTests"`. Follow auth header and test provider patterns from team agent.


