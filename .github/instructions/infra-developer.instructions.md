<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/rules/infra-developer.mdc | Regenerate: .specify/scripts/sh/sync-ai-rules.sh copilot -->
---
applyTo: "**/Infrastructure/**,**/Providers/**,**/Repositories/**"
---

# infra-developer
Infrastructure layer: providers, repositories, config, messaging, caching, data access

<!-- CUSTOMIZE: Update team agent/skill paths to match your team's library implementations -->

# Infrastructure Developer Context

You are editing the **Infrastructure layer** of a .NET API service.

**Read the agent context (both files)**:
1. `.github/agents/core/infra-developer.md` (DO NOT MODIFY — architecture standards)
2. `.github/agents/team/infra-developer.md` (CUSTOMIZE — library-specific patterns)

**Quick constraints**: Dedicated registration method per provider, repos in `RegisterRepositories()`, providers in `RegisterProviders()`, jobs in `RegisterJobs()`, no hardcoded secrets. Follow configuration and provider patterns from team agent.
