using eToro.Infrastructure.CentralConfigurationManager.Interfaces;
using eToro.Infrastructure.Providers.Rest.DependencyInjection.Extensions;
using eToro.Infrastructure.Tests.System.Bootstrap;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Concrete;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Interfaces;

namespace dor-cytech-poc1.Tests.System.Bootstrap
{
    /// <summary>
    /// Bootstrapper for system tests. Configures DI container and initializes test dependencies.
    /// TODO: Update ApplicationName and add your providers.
    /// </summary>
    public class SystemTestBootstrapper : BootstrapperBase<ISystemTestConfigurationProvider, SystemTestConfigurationProvider>
    {
        private const int InitializationDelaySeconds = 5;

        // TODO: Update this to your application name
        protected override string ApplicationName => "TemplateApiSystemTests";

        protected override void AddDependencies(IServiceCollection services)
        {
            // TODO: Register REST providers for system tests
            services.AddRestProvider<ITemplateApiProvider, TemplateApiProvider>();
            services.AddRestProvider<IStsOAuthApiProvider, StsOAuthApiProvider>();
        }

        protected override async Task UseDependenciesAsync(IApplicationBuilder app)
        {
            var systemTestConfigurationProvider = (SystemTestConfigurationProvider)app.ApplicationServices
                .GetRequiredService<ISystemTestConfigurationProvider>();
            var ccm = app.ApplicationServices.GetRequiredService<ICcm>();
            systemTestConfigurationProvider.Initialize(ccm);

            // Allow time for CCM to initialize
            await Task.Delay(TimeSpan.FromSeconds(InitializationDelaySeconds));
        }
    }
}
