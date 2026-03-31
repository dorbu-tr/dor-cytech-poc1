using eToro.Infrastructure.Tests.System.Providers.Abstract;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Interfaces;

namespace dor-cytech-poc1.Tests.System.Infrastructure.Providers.Concrete
{
    /// <summary>
    /// Configuration provider implementation for system tests.
    /// Retrieves configuration values from CCM for test environments.
    /// TODO: Update CCM key names to match your Etcd configuration.
    /// </summary>
    public class SystemTestConfigurationProvider : ConfigurationProviderBase, ISystemTestConfigurationProvider
    {
        // TODO: Update these CCM key names to match your Etcd configuration
        public string ApiBaseUrl => _ccm.GetValue("TemplateApiUrl");

        public int Gcid => _ccm.GetValue<int>("Gcid");

        public string StsOAuthApiBaseUrl => _ccm.GetValue("StsOAuthApiUrl");

        public string StsOAuthApiKey => _ccm.GetValue("StsOAuthApiKey");

        // TODO: Add additional configuration properties
        // Example:
        // public int DefaultResourceId => _ccm.GetValue<int>("DefaultResourceId");
    }
}
