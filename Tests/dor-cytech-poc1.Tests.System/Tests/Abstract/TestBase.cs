using eToro.Infrastructure.Tests.System.Bootstrap;
using dor-cytech-poc1.Tests.System.Bootstrap;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Concrete;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Dto.Requests;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Interfaces;

namespace dor-cytech-poc1.Tests.System.Tests.Abstract
{
    /// <summary>
    /// Base class for all system tests.
    /// Provides access to configured providers and common test utilities.
    /// IMPORTANT: System tests are written but only executed by CI/CD pipelines - DO NOT run locally.
    /// </summary>
    [TestFixture]
    [Category("SystemTests")]
    public abstract class TestBase : SystemTestBase<SystemTestBootstrapper, ISystemTestConfigurationProvider, SystemTestConfigurationProvider>
    {
        protected ISystemTestConfigurationProvider ConfigurationProvider;
        protected ITemplateApiProvider TemplateApiProvider;
        protected IStsOAuthApiProvider StsOAuthApiProvider;

        /// <summary>
        /// Default scope ID for eToro authentication.
        /// </summary>
        protected const int EtoroDefaultScopeId = 5;

        /// <summary>
        /// Default application name for token generation.
        /// </summary>
        protected const string DefaultApplicationName = "eToro";

        /// <summary>
        /// Token expiration time in seconds (5 minutes).
        /// </summary>
        protected const int TokenExpiresInSeconds = 5 * 60;

        // Cache the token to avoid generating a new one for each test
        private string _cachedAccessToken;

        [OneTimeSetUp]
        public void Init()
        {
            ConfigurationProvider = GetRequiredService<ISystemTestConfigurationProvider>();
            TemplateApiProvider = GetRequiredService<ITemplateApiProvider>();
            StsOAuthApiProvider = GetRequiredService<IStsOAuthApiProvider>();
        }

        /// <summary>
        /// Gets an access token with default permissions for the configured test user.
        /// </summary>
        /// <returns>A valid STS access token.</returns>
        protected async Task<string> GetAccessTokenAsync()
        {
            // Return cached token if available
            if (!string.IsNullOrEmpty(_cachedAccessToken))
                return _cachedAccessToken;

            return await GetAccessTokenAsync(new HashSet<int> { 1, 2, 3, 5, 6 }, null, DefaultApplicationName);
        }

        /// <summary>
        /// Gets an access token for the configured test user with specific scopes.
        /// </summary>
        /// <param name="authorizedScopeIds">The scope IDs to authorize.</param>
        /// <param name="additionalClaims">Optional additional claims to include in the token.</param>
        /// <param name="applicationName">The application name for the token.</param>
        /// <returns>A valid STS access token.</returns>
        protected async Task<string> GetAccessTokenAsync(
            ISet<int> authorizedScopeIds,
            IDictionary<string, string> additionalClaims,
            string applicationName)
        {
            var response = await StsOAuthApiProvider.CreateAccessTokenAsync(new CreateAccessTokenRequest
            {
                Gcid = ConfigurationProvider.Gcid,
                ApplicationName = applicationName,
                AuthorizedScopeIds = authorizedScopeIds,
                AdditionalClaims = additionalClaims,
                ExpiresInSeconds = TokenExpiresInSeconds
            });

            _cachedAccessToken = response.Token.Jwt;
            return _cachedAccessToken;
        }
    }
}
