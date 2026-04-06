<!-- TEAM-SPECIFIC: This file implements configuration patterns using eToro Trading NuGets — CCM, KeyVault, SCB, RegisterAutoUpdatedConfiguration. Teams using different libraries: replace this file with your library-specific implementations. -->

# Trading Configuration Patterns (CCM/KeyVault/SCB)

## When to Use This Skill

Use when implementing: configuration classes, CCM (etcd) config, KeyVault secrets, SCB (Service Config Broker), RegisterAutoUpdatedConfiguration, appsettings.json, environment-specific config.

## Configuration Sources

Trading services use three config sources — NOT vanilla `appsettings.json` binding:

| Source | Purpose | Package |
|--------|---------|---------|
| **CCM** (etcd) | Dynamic runtime config | `eToro.Trading.Configuration.Providers.Ccm` |
| **KeyVault** | Secrets (connection strings, API keys) | `eToro.Trading.Configuration.Providers.KeyVault` |
| **SCB** | Service config broker (RabbitMQ, Redis, env) | `eToro.Trading.Configuration.Providers.Scb` |

## Program.cs ConfigureHost Pattern (NON-NEGOTIABLE)

ConfigureHost is defined as a **local function** in Program.cs (verified in trading-orders-api, trading-copy-api, trading-settings-api). The LoggerWrapper is created once at the top of Program.cs and reused:

```csharp
var loggerWrapper = new LoggerWrapper();
// ...
void ConfigureHost(WebApplicationBuilder builder, IConfiguration configuration)
{
    builder.Host.AddFrameworkLogger(loggerWrapper)
        .ConfigureLogging((_, configLogging) => { configLogging.AddLog4Net(); })
        .ConfigureAppConfiguration((hostBuilderContext, configurationBuilder) =>
        {
            configurationBuilder
                .RegisterConfigurationServicesToContext(hostBuilderContext)
                .AddKeyVaultProvider(new {ServiceName}KeyVaultConfigurations())
                .AddCcm()
                .AddScb(scbSource =>
                {
                    scbSource.Builder
                        .SetDefaultConfigurationSection({ServiceName}Configuration.ConfigurationSection)
                        .AddScbOverride<{ServiceName}Configuration>(
                            scb => scb.GetGlobalDetails("IsRealEnvironment"),
                            c => c.IsRealEnvironment);
                });
        })
        .ConfigureServices((hostBuilderContext, services) =>
        {
            services.AddHealthChecks();
            services
                .AddSingletonFromContext<ICcm>(hostBuilderContext)
                .AddSingletonFromContext<ISCBFacade>(hostBuilderContext)
                .AddSingletonFromContext<IKeyVaultSecretProvider>(hostBuilderContext)
                .RegisterLoggers()
                .RegisterConfigurations()
                .ConfigureHealthChecks()
                .RegisterTypes();
        });
}
```

**Key requirements:**
- `AddFrameworkLogger(new LoggerWrapper())` — NOT `builder.Logging.AddConsole()`
- `AddKeyVaultProvider` — secrets from Azure KeyVault
- `AddCcm()` — dynamic runtime config from etcd
- `AddScb(...)` — service config broker for Redis, RabbitMQ, environment
- `AddSingletonFromContext<ICcm>`, `<ISCBFacade>`, `<IKeyVaultSecretProvider>` — mandatory context registrations

## Configuration Bootstrap Registration

```csharp
public static class ConfigurationsBootstrap
{
    public static IServiceCollection RegisterConfigurations(this IServiceCollection serviceCollection)
    {
        serviceCollection
            .RegisterAutoUpdatedConfiguration<{ServiceName}Configuration>(
                {ServiceName}Configuration.ConfigurationSection)
            .WithSubConfiguration(c => c.{ServiceName}AppSecret)
            .WithSubConfiguration(c => c.EtoroDatabase)
            .WithSubConfiguration(c => c.RetryPolicyConfig)
            .WithSubConfiguration(c => c.BaseRepositoryConfiguration)
            .WithSubConfiguration(c => c.HealthChecksConfig);

        serviceCollection.AddSingleton<IEnvironmentConfig>(
            sp => sp.GetRequiredService<{ServiceName}Configuration>());

        return serviceCollection;
    }
}
```

**Order matters**: `HealthChecksConfig` MUST be last. Additional sub-configs are added conditionally based on service type.

## Full Configuration Reference

Read [references/config-patterns.md](references/config-patterns.md) for:
- Main configuration class structure
- KeyVault configuration with `[ValueCensorLogicAll]` attributes
- Sub-configuration classes (HealthChecksConfig, RetryPolicyConfig, etc.)
- appsettings.json patterns per environment
- Environment reference table (QA, Staging, Production)
- Aggregator service configuration (no database)
- Cached repository configuration
- Configuration anti-patterns
