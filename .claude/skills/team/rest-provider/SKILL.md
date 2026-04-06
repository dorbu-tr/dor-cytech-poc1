<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/team/rest-provider/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
<!-- TEAM-SPECIFIC: This file implements external API provider patterns using IHttpClientFactory + Polly resilience. Verified against trading-framework, trading-shared, and trading-data-api GitHub source code. -->

# Trading REST Provider Patterns

## When to Use This Skill

Use when implementing: external API integrations, REST providers, Polly resilience pipelines, circuit breaker, retry policies, timeout policies, health checks for external dependencies.

## Provider Architecture

Trading services build REST providers using `IHttpClientFactory` typed clients + Polly `ResiliencePipeline`.

> **IMPORTANT**: `eToro.Trading.Infrastructure.Providers` contains domain-specific providers (InstrumentPriceProvider, SettlementProvider, etc.) — NOT a generic REST provider base class. For custom REST providers, use `IHttpClientFactory` + `HttpClient` directly.

> **IMPORTANT**: `Framework.FaultTolerance` is for **SQL retry only** (uses Enterprise Library `RetryPolicy` with SQL error detection strategies like `SqlDatabaseTransientErrorDetectionStrategy`). Do NOT use it for HTTP resilience — use Polly.

```csharp
public sealed class {ApiName}Provider : I{ApiName}Provider
{
    private readonly HttpClient _httpClient;
    private readonly ResiliencePipeline _resiliencePipeline;
    private readonly ILogger<{ApiName}Provider> _logger;

    public {ApiName}Provider(
        HttpClient httpClient,
        ResiliencePipeline resiliencePipeline,
        ILogger<{ApiName}Provider> logger)
    {
        _httpClient = httpClient;
        _resiliencePipeline = resiliencePipeline;
        _logger = logger;
    }

    public async Task<{ApiName}Response> GetByIdAsync(int id, CancellationToken ct = default)
    {
        return await _resiliencePipeline.ExecuteAsync(async token =>
        {
            _logger.LogInfo($"Calling {ApiName} API for id={id}");
            var response = await _httpClient.GetAsync($"/api/v1/resource/{id}", token);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadFromJsonAsync<{ApiName}Response>(token);
        }, ct);
    }
}
```

## DI Registration (IHttpClientFactory Typed Client)

```csharp
public static IServiceCollection AddHttpClients(this IServiceCollection services)
{
    services.AddHttpClient<I{ApiName}Provider, {ApiName}Provider>("{ApiName}", (sp, client) =>
    {
        var config = sp.GetRequiredService<{ApiName}Configuration>();
        client.BaseAddress = new Uri(config.Url);
        client.Timeout = TimeSpan.FromSeconds(config.TimeoutSeconds);
    });
    return services;
}
```

## Polly Resilience Pipeline (v8)

From `trading-opstool-api` (production pattern):

```csharp
public static class RetryPolicyBootstrap
{
    public static IServiceCollection AddRetryPolicy(this IServiceCollection services)
    {
        services.AddSingleton(sp =>
        {
            var config = sp.GetRequiredService<RetryPolicyConfiguration>();
            return new ResiliencePipelineBuilder()
                .AddRetry(new RetryStrategyOptions
                {
                    MaxRetryAttempts = config.NumOfRetries,
                    Delay = config.TimeBetweenRetries,
                    BackoffType = DelayBackoffType.Exponential,
                    UseJitter = true
                })
                .AddTimeout(TimeSpan.FromSeconds(config.CommandTimeout))
                .Build();
        });
        return services;
    }
}
```

## Health Check for External API

```csharp
// In HealthCheckBootstrap, use HealthCheckHttpCommandBuilder from Bootstrap.HealthCheck:
new HealthCheckHttpCommandBuilder("{ApiName}", config => config.HealthCheckUrl)
```

## NuGet Package Catalog

For the complete Trading NuGet package catalog organized by service type, read [references/nuget-packages.md](references/nuget-packages.md).

## Implementation Pitfalls

Read [references/pitfalls.md](references/pitfalls.md) for common mistakes and pre-implementation checklist.

## Required NuGet Packages

```xml
<!-- Infrastructure project -->
<PackageReference Include="Microsoft.Extensions.Http" Version="8.0.0" />
<PackageReference Include="Polly" Version="8.5.0" />
<PackageReference Include="Polly.Extensions" Version="8.5.0" />

<!-- NOT required for HTTP providers: -->
<!-- eToro.Trading.Infrastructure.Providers — domain-specific providers, not a REST base class -->
<!-- eToro.Trading.Framework.FaultTolerance — SQL retry only, not for HTTP -->
```
