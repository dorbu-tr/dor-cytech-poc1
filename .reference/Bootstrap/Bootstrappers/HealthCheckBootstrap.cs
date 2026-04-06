using eToro.Trading.Bootstrap.HealthCheck;
using eToro.Trading.Bootstrap.HealthCheck.Builders;
using eToro.Trading.Bootstrap.Models.Configurations;
using eToro.Trading.{ServiceName}.Bootstrap.Configurations;
using Microsoft.Extensions.DependencyInjection;

namespace eToro.Trading.{ServiceName}.Bootstrap.Bootstrappers;

public static class HealthCheckBootstrap
{
    /// <summary>
    /// Registers health check commands using Bootstrap.HealthCheck builders.
    /// Available builders: HealthCheckDatabaseCommandBuilder, HealthCheckHttpCommandBuilder,
    /// HealthCheckRabbitMqCommandBuilder, HealthCheckRedisCommandBuilder.
    /// </summary>
    public static IServiceCollection ConfigureHealthChecks(this IServiceCollection serviceCollection)
        => serviceCollection.ConfigureHealthChecks(
            sp => sp.GetRequiredService<{ServiceName}Configuration>().HealthCheckCacheResultInSeconds,
            new HealthCheckDatabaseCommandBuilder("etoroDb",
                sp => sp.GetRequiredService<EtoroDatabaseConfiguration>().ConnectionString));

    // For aggregator services (HTTP dependency instead of DB):
    // => serviceCollection.ConfigureHealthChecks(
    //     sp => sp.GetRequiredService<{ServiceName}Configuration>().HealthCheckCacheResultInSeconds,
    //     new HealthCheckHttpCommandBuilder("{ApiName}",
    //         sp => sp.GetRequiredService<{ApiName}Configuration>().HealthCheckUrl));
}
