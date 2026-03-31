<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/rules/api-developer.mdc | Regenerate: .specify/scripts/sh/sync-ai-rules.sh copilot -->
---
applyTo: "**/Api/**,**/Controllers/**"
---

# api-developer
API layer: controllers, DTOs, validation, Swagger, route conventions

<!-- CUSTOMIZE: Update team agent/skill paths to match your team's library implementations -->

# API Developer Context

You are editing the **API layer** of a .NET API service.

**Read the agent context (both files)**:
1. `.github/agents/core/api-developer.md` (DO NOT MODIFY — architecture standards)
2. `.github/agents/team/api-developer.md` (CUSTOMIZE — library-specific patterns)

**Quick constraints**: Single request object per action, routes `api/v1/{resource}`, binding attributes on DTO properties not method params, `Internalize()`/`Externalize()` extensions, `FromData()` on nested data items. Follow auth and validation patterns from team agent.
