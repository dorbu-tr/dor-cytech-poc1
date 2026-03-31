<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/rules/test-developer.mdc | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
<!-- Description: Tests: component tests, system tests, bootstrapper, auth mocking, infrastructure mocking -->

<!-- CUSTOMIZE: Update team agent/skill paths to match your team's library implementations -->

# Test Developer Context

You are editing **tests** for a .NET API service.

**Read the agent context (both files)**:
1. `.claude/agents/core/test-developer.md` (DO NOT MODIFY — architecture standards)
2. `.claude/agents/team/test-developer.md` (CUSTOMIZE — library-specific patterns)

**Quick constraints**: NUnit + Shouldly only, `TestsBase : ComponentTestBase<Startup>`, `GetServiceMock<T>()`, `.Reset()`, system tests write-only (never run locally), `dotnet test --filter "Category=ComponentTests"`. Follow auth header and test provider patterns from team agent.
