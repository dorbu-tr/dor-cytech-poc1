using eToro.Trading.Bootstrap.Extensions.Configuration;
using eToro.Trading.{ServiceName}.Bootstrap.Configurations;
using Microsoft.Extensions.DependencyInjection;

namespace eToro.Trading.{ServiceName}.Bootstrap.Bootstrappers;

/// <summary>
/// Registers CCM auto-updated configuration with sub-configuration extraction.
/// Sub-configurations are individually injectable via DI.
/// Pattern verified in trading-opstool-api, trading-orders-api.
///
/// NOTE: AuthorizationConfiguration is service-specific (defined in Api/Configuration/).
/// HealthChecksConfig is NOT a NuGet type — use HealthCheckCacheResultInSeconds int property instead.
/// </summary>
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
            .WithSubConfiguration(c => c.BaseRepositoryConfiguration);

        return serviceCollection;
    }
}
