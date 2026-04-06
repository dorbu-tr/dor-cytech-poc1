using eToro.Trading.Bootstrap.Models.Configurations;

namespace eToro.Trading.{ServiceName}.Bootstrap.Configurations;

/// <summary>
/// Main configuration class — registered via RegisterAutoUpdatedConfiguration.
/// Sub-configurations are extracted via .WithSubConfiguration() for DI injection.
/// 
/// NOTE: AuthorizationConfiguration, HealthChecksConfig, and IEnvironmentConfig
/// are NOT shipped in any Trading NuGet. Define them per-service.
/// Only EtoroDatabaseConfiguration, RetryPolicyConfiguration, SqlDatabaseConfiguration,
/// ConnectionConfiguration, and BaseRepositoryConfiguration come from Bootstrap.Models.
/// </summary>
public sealed class {ServiceName}Configuration
{
    public const string ConfigurationSection = "{ServiceName}";

    // Service-specific (defined locally in Api/Configuration/)
    public AuthorizationConfiguration {ServiceName}AppSecret { get; set; }

    // From Bootstrap.Models.Configurations
    public EtoroDatabaseConfiguration EtoroDatabase { get; set; }
    public RetryPolicyConfiguration RetryPolicyConfig { get; set; }
    public SqlDatabaseConfiguration BaseRepositoryConfiguration { get; set; }
    public ConnectionConfiguration TradingRabbitConnection { get; set; }

    // Service-specific
    public bool IsRealEnvironment { get; set; }
    public int HealthCheckCacheResultInSeconds { get; set; } = 30;
}
