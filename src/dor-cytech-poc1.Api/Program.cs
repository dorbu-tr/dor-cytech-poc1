using dor-cytech-poc1.Api.Extensions;
using dor-cytech-poc1.Bootstrap.Bootstrappers;
using eToro.Trading.Bootstrap.Logger;
using Framework.Log;

var loggerWrapper = new LoggerWrapper();

var builder = WebApplication.CreateBuilder(args);
var configuration = builder.Configuration;

ConfigureHost(builder, configuration);

builder.ConfigureWebService();

if (!builder.Environment.IsProduction())
    builder.RegisterSwagger(configuration);

var app = builder.Build();

app.ConfigureWebApplication();

await app.RunAsync();

void ConfigureHost(WebApplicationBuilder builder, IConfiguration configuration)
{
    builder.Host.AddFrameworkLogger(loggerWrapper)
        .ConfigureLogging((_, configLogging) => { configLogging.AddLog4Net(); })
        .ConfigureAppConfiguration((hostBuilderContext, configurationBuilder) =>
        {
            // Uncomment and configure for your service:
            // configurationBuilder
            //     .RegisterConfigurationServicesToContext(hostBuilderContext)
            //     .AddKeyVaultProvider(new {ServiceName}KeyVaultConfigurations())
            //     .AddCcm()
            //     .AddScb(scbSource =>
            //     {
            //         scbSource.Builder
            //             .SetDefaultConfigurationSection({ServiceName}Configuration.ConfigurationSection);
            //     });
        })
        .ConfigureServices((hostBuilderContext, services) =>
        {
            services.AddHealthChecks();

            // Context-based singletons (uncomment after configuring CCM/SCB/KeyVault):
            // services
            //     .AddSingletonFromContext<ICcm>(hostBuilderContext)
            //     .AddSingletonFromContext<ISCBFacade>(hostBuilderContext)
            //     .AddSingletonFromContext<IKeyVaultSecretProvider>(hostBuilderContext);

            services
                .RegisterLoggers()
                // .RegisterConfigurations()    // See Bootstrap/Bootstrappers/ConfigurationsBootstrap.cs
                // .ConfigureHealthChecks()     // See Bootstrap/Bootstrappers/HealthCheckBootstrap.cs
                .RegisterTypes(typeof(Program).Assembly);
        });
}

// Make the implicit Program class accessible for WebApplicationFactory<Program> in tests
public partial class Program { }
