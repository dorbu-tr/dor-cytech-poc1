using eToro.Infrastructure.Tests.System.Providers.Interfaces;

namespace dor-cytech-poc1.Tests.System.Infrastructure.Providers.Interfaces
{
    /// <summary>
    /// Configuration provider interface for system tests.
    /// Provides access to test environment configuration values from CCM.
    /// TODO: Add properties specific to your service.
    /// </summary>
    public interface ISystemTestConfigurationProvider : IConfigurationProvider
    {
        /// <summary>
        /// Base URL of the API under test.
        /// </summary>
        string ApiBaseUrl { get; }

        /// <summary>
        /// Global Customer ID for test user.
        /// </summary>
        int Gcid { get; }

        /// <summary>
        /// STS OAuth API base URL for token generation.
        /// </summary>
        string StsOAuthApiBaseUrl { get; }

        /// <summary>
        /// API key for STS OAuth API.
        /// </summary>
        string StsOAuthApiKey { get; }

        // TODO: Add additional configuration properties as needed
        // Example:
        // int DefaultResourceId { get; }
    }
}
