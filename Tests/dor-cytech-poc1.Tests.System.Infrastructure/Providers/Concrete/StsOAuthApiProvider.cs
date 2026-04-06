using System.Net.Mime;
using System.Text;
using eToro.Infrastructure.Monitoring.Abstract;
using eToro.Infrastructure.Providers.Rest;
using eToro.Infrastructure.Providers.Rest.Entities;
using Newtonsoft.Json;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Dto.Requests;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Dto.Responses;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Interfaces;

namespace dor-cytech-poc1.Tests.System.Infrastructure.Providers.Concrete
{
    /// <summary>
    /// STS OAuth API provider implementation for system tests.
    /// </summary>
    public sealed class StsOAuthApiProvider : RestProviderBase, IStsOAuthApiProvider
    {
        private readonly ISystemTestConfigurationProvider _configurationProvider;

        public StsOAuthApiProvider(ISystemTestConfigurationProvider configurationProvider, IMonitor monitor)
            : base(monitor)
        {
            _configurationProvider = configurationProvider;
        }

        public override string Name => nameof(StsOAuthApiProvider);
        public override bool IsMandatory => true;
        protected override string BaseUrl => _configurationProvider.StsOAuthApiBaseUrl;
        protected override int TimeoutInMs => 30000;

        public async Task<CreateAccessTokenResponse> CreateAccessTokenAsync(CreateAccessTokenRequest request)
        {
            var payload = new
            {
                applicationName = request.ApplicationName,
                authorizedScopeIds = request.AuthorizedScopeIds,
                additionalClaims = request.AdditionalClaims,
                expiresInSeconds = request.ExpiresInSeconds
            };

            var restRequest = new RestRequest(HttpMethod.Post, $"api/v3/users/{request.Gcid}/tokens", nameof(CreateAccessTokenAsync))
            {
                Body = new StringContent(
                    JsonConvert.SerializeObject(payload),
                    Encoding.UTF8,
                    MediaTypeNames.Application.Json),
                Headers = new Dictionary<string, string>
                {
                    ["x-api-key"] = _configurationProvider.StsOAuthApiKey
                }
            };

            var response = await SendRequestGetResponseAsync<CreateAccessTokenResponse>(restRequest);
            return response.Content;
        }
    }
}
