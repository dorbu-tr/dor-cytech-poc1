# Configuration Provider Patterns

## Table of Contents
- [Configuration Class Structure](#configuration-class-structure)
- [KeyVault Configuration](#keyvault-configuration)
- [Sub-Configuration Classes](#sub-configuration-classes)
- [Bootstrap Registration](#bootstrap-registration)
- [appsettings Patterns](#appsettings-patterns)
- [Environment Reference Table](#environment-reference-table)
- [Configuration Anti-Patterns](#configuration-anti-patterns)

---

## Configuration Class Structure

**Main config** (`Bootstrap/Configurations/{ServiceName}Configuration.cs`):

```csharp
using eToro.Trading.Bootstrap.Models.Configurations;
using eToro.Trading.{ServiceName}.Application.Configuration;

namespace eToro.Trading.{ServiceName}.Bootstrap.Configurations;

public class {ServiceName}Configuration : IEnvironmentConfig
{
    public const string ConfigurationSection = "{ServiceName}";

    public EtoroDatabaseConfiguration EtoroDatabase { get; set; }
    public RetryPolicyConfig RetryPolicyConfig { get; set; }
    public HealthChecksConfig HealthChecksConfig { get; init; }
    public bool IsRealEnvironment { get; set; }
    public AuthorizationConfiguration {ServiceName}AppSecret { get; set; }
    public BaseRepositoryConfiguration BaseRepositoryConfiguration { get; set; }
    public {Feature}CachedRepositoryConfiguration {Feature}CachedRepositoryConfiguration { get; set; } = new();
    public ConnectionConfiguration TradingRabbitConnection { get; set; }
}
```

## KeyVault Configuration

`Bootstrap/Configurations/{ServiceName}KeyVaultConfigurations.cs`:

```csharp
using eToro.Trading.Configuration.Providers.KeyVault.Configurations;
using eToro.Trading.Configuration.Providers.KeyVault.Configurations.Attributes;
using eToro.Trading.Configuration.Providers.KeyVault.Configurations.Attributes.ValueCensorLogic;

public class {ServiceName}KeyVaultConfigurations : KeyVaultConfigurationWithCcmLogin
{
    [ValueCensorLogicAll]
    [KeyVaultConfigurationOverride(
        {ServiceName}Configuration.ConfigurationSection,
        nameof({ServiceName}Configuration.{ServiceName}AppSecret),
        nameof({ServiceName}Configuration.{ServiceName}AppSecret.ReadOnlyAppSecret))]
    public string {ServiceName}ReadOnlyAppSecret { get; set; } = "ReadOnlyAppSecret";

    [ValueCensorLogicAll]
    [KeyVaultConfigurationOverride(
        {ServiceName}Configuration.ConfigurationSection,
        nameof({ServiceName}Configuration.{ServiceName}AppSecret),
        nameof({ServiceName}Configuration.{ServiceName}AppSecret.ReadWriteAppSecret))]
    public string {ServiceName}ReadWriteAppSecret { get; set; } = "ReadWriteAppSecret";

    [ValueCensorLogicConnectionString]
    [KeyVaultConfigurationOverride(
        {ServiceName}Configuration.ConfigurationSection,
        nameof({ServiceName}Configuration.EtoroDatabase),
        nameof({ServiceName}Configuration.EtoroDatabase.ConnectionString))]
    public string EtoroDbConnectionString { get; set; } = "EtoroDbConnectionString";
}
```

**KeyVault attributes:**

| Attribute | Use For |
|-----------|---------|
| `[ValueCensorLogicAll]` | Secrets, API keys, tokens |
| `[ValueCensorLogicConnectionString]` | Database connection strings |
| `[KeyVaultConfigurationOverride]` | Maps KeyVault secret to config property |

## Sub-Configuration Classes

```csharp
// HealthChecksConfig
public class HealthChecksConfig
{
    public TimeSpan HealthCheckCacheResult { get; set; }
}

// RetryPolicyConfig
public class RetryPolicyConfig : RetryPolicyConfiguration
{
    public int CommandTimeout { get; set; }
}

// IEnvironmentConfig (Application layer)
public interface IEnvironmentConfig
{
    bool IsRealEnvironment { get; }
}
```

## Bootstrap Registration

```csharp
public static class ConfigurationsBootstrap
{
    public static IServiceCollection RegisterConfigurations(this IServiceCollection serviceCollection)
    {
        serviceCollection
            .RegisterAutoUpdatedConfiguration<{ServiceName}Configuration>(
                {ServiceName}Configuration.ConfigurationSection)
            .WithSubConfiguration(c => c.EtoroDatabase)
            .WithSubConfiguration(c => c.RetryPolicyConfig)
            .WithSubConfiguration(c => c.HealthChecksConfig)
            .WithSubConfiguration(c => c.{ServiceName}AppSecret)
            .WithSubConfiguration(c => c.BaseRepositoryConfiguration);

        serviceCollection.AddSingleton<IEnvironmentConfig>(
            sp => sp.GetRequiredService<{ServiceName}Configuration>());

        return serviceCollection;
    }
}
```

## Configuration File Mapping

| Property | appsettings Path | KeyVault Secret |
|----------|-----------------|-----------------|
| `EtoroDatabase.ConnectionString` | -- | `EtoroDbConnectionString` |
| `AppSecret.ReadOnlyAppSecret` | -- | `ReadOnlyAppSecret` |
| `AppSecret.ReadWriteAppSecret` | -- | `ReadWriteAppSecret` |
| `RetryPolicyConfig.NumOfRetries` | `{ServiceName}.RetryPolicyConfig.NumOfRetries` | -- |
| `HealthChecksConfig.HealthCheckCacheResult` | `{ServiceName}.HealthChecksConfig.HealthCheckCacheResult` | -- |

## appsettings Patterns

**Base** (`appsettings.json`):
```json
{
  "Logging": { "LogLevel": { "Default": "Information" } },
  "AllowedHosts": "*",
  "App": { "Title": "{ServiceName}", "Version": "v1", "Location": "local" },
  "KeyVault": {
    "Uri": "https://qa-{service-name}-r-kv-we.vault.azure.net/",
    "EtoroDbConnectionString": "QA2-MainDbConnectionString"
  },
  "CcmConfiguration": {
    "Uris": ["http://int-ccm.trad.local:2379"],
    "Environment": "qa-trading",
    "Node": "T-QA2-AZR",
    "Service": "{service-name}-real"
  },
  "{ServiceName}": {
    "HealthChecksConfig": { "HealthCheckCacheResult": "0:00:20" },
    "RetryPolicyConfig": { "NumOfRetries": 2, "TimeBetweenRetries": "0:00:04", "CommandTimeout": 4 }
  }
}
```

**QA** (`appsettings.QA{N}-Real.json`):
```json
{
  "CcmConfiguration": { "Uris": ["http://int-ccm.trad.local:2379"], "Environment": "qa-trading", "Node": "T-QA{N}-AZR", "Service": "{service-name}-real" },
  "KeyVault": { "EtoroDbConnectionString": "QA{N}-MainDbConnectionString", "Uri": "https://qa-{service-name}-r-kv-we.vault.azure.net/" }
}
```

**Staging** (`appsettings.Staging-Real.json`):
```json
{
  "CcmConfiguration": { "Uris": ["http://stg-ccm.trad.local:2379"], "Environment": "staging", "Node": "", "Service": "{service-name}-real" },
  "KeyVault": { "CcmUserSecretName": "ccm-username", "CcmPasswordSecretName": "ccm-password", "EtoroDbConnectionString": "MainDbConnectionString", "Uri": "https://stg-{service-name}-r-kv-we.vault.azure.net/" },
  "InitializeApplicationInsights": true
}
```

**Production** (`appsettings.Production-Real-{Region}.json`):
```json
{
  "CcmConfiguration": { "Uris": ["http://AZR-CCM-W-VIP.prod.local:2379", "http://AZR-CCM-N-VIP.prod.local:2379"], "Environment": "prod-azure-{north|west}-eur", "Service": "{service-name}-real-{ne|we}" },
  "KeyVault": { "EtoroDbConnectionString": "MainDbConnectionString", "Uri": "https://prod-{service-name}-r-kv-{ne|we}.vault.azure.net/" },
  "InitializeApplicationInsights": true
}
```

## Environment Reference Table

| Environment | CCM URI | CCM Environment | DB Secret | KeyVault Pattern |
|-------------|---------|-----------------|-----------|-----------------|
| QA1-QA5 | `int-ccm.trad.local:2379` | `qa-trading` | `QA{N}-MainDbConnectionString` | `qa-{svc}-{r|d}-kv-we` |
| Staging | `stg-ccm.trad.local:2379` | `staging` | `MainDbConnectionString` | `stg-{svc}-{r|d}-kv-we` |
| Prod-North | `[W-VIP, N-VIP]` | `prod-azure-north-eur` | `MainDbConnectionString` | `prod-{svc}-{r|d}-kv-ne` |
| Prod-West | `[W-VIP, N-VIP]` | `prod-azure-west-eur` | `MainDbConnectionString` | `prod-{svc}-{r|d}-kv-we` |

Key: `{r|d}` = `-r-` for Real, `-d-` for Demo. QA uses prefixed secrets, Staging/Prod use non-prefixed.

## Aggregator Service Configuration Class

Aggregator services (no database) have a different configuration class structure:

```csharp
public class {ServiceName}Configuration : IEnvironmentConfig
{
    public const string ConfigurationSection = "{ServiceName}";

    // NO database properties (no EtoroDatabase, no RetryPolicyConfig)

    // External API provider configs (required for Aggregator)
    public {ExternalApi}ProviderConfiguration {ExternalApi}Provider { get; set; }
    public CircuitBreakerConfiguration CircuitBreaker { get; set; }

    // Common
    public HealthChecksConfig HealthChecksConfig { get; init; }
    public bool IsRealEnvironment { get; set; }
}
```

## Cached Repository Configuration Template

For features that cache data with a TTL:

```csharp
public class {Feature}CachedRepositoryConfiguration
{
    public TimeSpan {Feature}RepositoryCacheTtl { get; set; } = TimeSpan.FromHours(12);
    public string {Feature}_CACHE_KEY { get; set; }
}
```

Register as a sub-configuration: `.WithSubConfiguration(c => c.{Feature}CachedRepositoryConfig)`

## Configuration Anti-Patterns

- DO NOT hardcode secrets in configuration classes
- DO NOT miss `[ValueCensorLogic*]` on secret properties
- DO NOT use `IConfiguration` directly (use typed configuration)
- DO NOT create config classes without `WithSubConfiguration` registration
- DO NOT store connection strings in appsettings.json (use KeyVault)
- DO NOT miss `IEnvironmentConfig` registration
