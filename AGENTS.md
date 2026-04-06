<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->

# dor-cytech-poc1

Clean Architecture .NET API service built with the eToro SDD template.

**Tech Stack:** .NET 8, C#, Clean Architecture, NUnit, Shouldly

## Architecture Agents

Read the appropriate agent based on the layer you are working in. Each role has a core (architecture) and team (library-specific) variant in `.codex/agents/`.

### api-developer
Implements API layer: controllers, request/response DTOs, validation, mapping extensions, Swagger documentation, route conventions.
- Core: `.codex/agents/core-api-developer.md`
- Team: `.codex/agents/team-api-developer.md`

### app-developer
Implements Application layer: services with monitoring wrapping, event publishing, application DTOs (Parameters/Results/Data), application exceptions.
- Core: `.codex/agents/core-app-developer.md`
- Team: `.codex/agents/team-app-developer.md`

### infra-developer
Implements Infrastructure layer: REST providers, configuration, circuit breaker, health commands, external API integrations, repositories, messaging, caching.
- Core: `.codex/agents/core-infra-developer.md`
- Team: `.codex/agents/team-infra-developer.md`

### test-developer
Implements Component and System tests: test bootstrapper, auth mocking, test API providers, assertions, infrastructure mocking.
- Core: `.codex/agents/core-test-developer.md`
- Team: `.codex/agents/team-test-developer.md`

## Skills Reference

Skills are in `.codex/skills/`. Invoke with `$skill-name` in Codex.

### Core Skills

- **`$core-api-controllers`** (`.codex/skills/core-api-controllers/SKILL.md`)
- **`$core-api-design`** (`.codex/skills/core-api-design/SKILL.md`)
- **`$core-cluster-deployment`** (`.codex/skills/core-cluster-deployment/SKILL.md`)
- **`$core-component-testing`** (`.codex/skills/core-component-testing/SKILL.md`)
- **`$core-config-management`** (`.codex/skills/core-config-management/SKILL.md`)
- **`$core-data-repositories`** (`.codex/skills/core-data-repositories/SKILL.md`)
- **`$core-monitoring-logging`** (`.codex/skills/core-monitoring-logging/SKILL.md`)
- **`$core-readme-generation`** (`.codex/skills/core-readme-generation/SKILL.md`)
- **`$core-rest-providers`** (`.codex/skills/core-rest-providers/SKILL.md`)
- **`$core-security-review`** (`.codex/skills/core-security-review/SKILL.md`)
- **`$core-swagger-docs`** (`.codex/skills/core-swagger-docs/SKILL.md`)
- **`$core-system-testing`** (`.codex/skills/core-system-testing/SKILL.md`)

### Team Skills

- **`$team-api-controllers`** (`.codex/skills/team-api-controllers/SKILL.md`)
- **`$team-component-testing`** (`.codex/skills/team-component-testing/SKILL.md`)
- **`$team-config-ccm`** (`.codex/skills/team-config-ccm/SKILL.md`)
- **`$team-data-repositories`** (`.codex/skills/team-data-repositories/SKILL.md`)
- **`$team-monitoring-logging`** (`.codex/skills/team-monitoring-logging/SKILL.md`)
- **`$team-orchestration`** (`.codex/skills/team-orchestration/SKILL.md`)
- **`$team-rest-provider`** (`.codex/skills/team-rest-provider/SKILL.md`)
- **`$team-system-testing`** (`.codex/skills/team-system-testing/SKILL.md`)
- **`$team-worker-service`** (`.codex/skills/team-worker-service/SKILL.md`)

## Key Conventions

### api-developer
API layer: controllers, DTOs, validation, Swagger, route conventions

<!-- CUSTOMIZE: Update team agent/skill paths to match your team's library implementations -->

# API Developer Context

You are editing the **API layer** of a .NET API service.

**Read the agent context (both files)**:
1. `.codex/agents/core-api-developer.md` (DO NOT MODIFY — architecture standards)
2. `.codex/agents/team-api-developer.md` (CUSTOMIZE — library-specific patterns)

**Quick constraints**: Single request object per action, routes `api/v1/{resource}`, binding attributes on DTO properties not method params, `Internalize()`/`Externalize()` extensions, `FromData()` on nested data items. Follow auth and validation patterns from team agent.

### infra-developer
Infrastructure layer: providers, repositories, config, messaging, caching, data access

<!-- CUSTOMIZE: Update team agent/skill paths to match your team's library implementations -->

# Infrastructure Developer Context

You are editing the **Infrastructure layer** of a .NET API service.

**Read the agent context (both files)**:
1. `.codex/agents/core-infra-developer.md` (DO NOT MODIFY — architecture standards)
2. `.codex/agents/team-infra-developer.md` (CUSTOMIZE — library-specific patterns)

**Quick constraints**: Dedicated registration method per provider, repos in `RegisterRepositories()`, providers in `RegisterProviders()`, jobs in `RegisterJobs()`, no hardcoded secrets. Follow configuration and provider patterns from team agent.

### test-developer
Tests: component tests, system tests, bootstrapper, auth mocking, infrastructure mocking

<!-- CUSTOMIZE: Update team agent/skill paths to match your team's library implementations -->

# Test Developer Context

You are editing **tests** for a .NET API service.

**Read the agent context (both files)**:
1. `.codex/agents/core-test-developer.md` (DO NOT MODIFY — architecture standards)
2. `.codex/agents/team-test-developer.md` (CUSTOMIZE — library-specific patterns)

**Quick constraints**: NUnit + Shouldly only, `TestsBase : ComponentTestBase<Startup>`, `GetServiceMock<T>()`, `.Reset()`, system tests write-only (never run locally), `dotnet test --filter "Category=ComponentTests"`. Follow auth header and test provider patterns from team agent.


