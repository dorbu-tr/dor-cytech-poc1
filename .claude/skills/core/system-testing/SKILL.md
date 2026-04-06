<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/core/system-testing/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
---
name: system-testing
description: System test architecture patterns for writing real HTTP tests against deployed environments. Use when implementing system tests, real HTTP endpoint tests, environment-specific configuration, or write-only test projects. Do NOT run system tests locally — CI/CD only.
---

# System Testing Patterns

## System Test Architecture

System tests run against **real deployed environments** using real HTTP calls. They are WRITTEN during implementation but NEVER run locally -- only in CI/CD pipelines.

### System Test Bootstrapper
The bootstrapper extends a system test base class and registers:
- Your service's test API provider (for making HTTP calls to your API)
- An auth token provider (for generating real auth tokens)

### System Test Configuration Provider
Provides environment-specific values loaded from your config management system:
```csharp
public interface ISystemTestConfigurationProvider
{
    string ApiBaseUrl { get; }
    int TestUserId { get; }
    string AuthTokenApiBaseUrl { get; }
    string AuthTokenApiKey { get; }
    string ApiKey { get; }  // For backend-to-backend endpoints
}
```

### Test Base Class
```csharp
[TestFixture]
[Category("SystemTests")]
public abstract class TestBase : SystemTestBase<SystemTestBootstrapper>
{
    protected ISystemTestConfigurationProvider ConfigurationProvider;
    protected IServiceApiProvider ServiceApiProvider;
    private string _cachedAccessToken;

    [OneTimeSetUp]
    public void Init()
    {
        ConfigurationProvider = GetRequiredService<ISystemTestConfigurationProvider>();
        ServiceApiProvider = GetRequiredService<IServiceApiProvider>();
    }

    protected async Task<string> GetAccessTokenAsync()
    {
        if (!string.IsNullOrEmpty(_cachedAccessToken)) return _cachedAccessToken;
        // Generate real auth token using auth token provider
        _cachedAccessToken = await GenerateAuthToken();
        return _cachedAccessToken;
    }
}
```

## System Test appsettings.json Pattern

Required files in `Tests.System/` project:
- `appsettings.local.json` -- Local dev
- `appsettings.integration.json` -- CI/CD INT environment
- `appsettings.staging.json` -- CI/CD STG environment
- `appsettings.production.json` -- CI/CD PROD environment

ALL files follow config-management-only pattern. No application config in appsettings.

## Backend-to-Backend Authentication -- System Test Pattern

For endpoints protected by backend auth (API key):
- Read API key from `ConfigurationProvider.ApiKey` (stored in config management/secret vault)
- Pass API key directly to test provider method
- No auth token generation needed

## System Test Design Rules
- ONLY test full end-to-end scenarios (happy-flow)
- Use real auth tokens for client-facing endpoints
- Verify response structure and integration
- Handle missing data with `Assert.Ignore()`
- DO NOT test validation (component tests cover that)
- DO NOT test non-happy-flow scenarios (401, 400) -- those belong in component tests
- When operations form a natural CRUD chain, PREFER merging into a single lifecycle test (Create -> Get -> Update -> Delete)
- DO NOT use `[Ignore]` attributes
- DO NOT run locally -- CI/CD only
