using eToro.Infrastructure.Providers.Rest.Interfaces;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Dto.Requests;
using dor-cytech-poc1.Tests.System.Infrastructure.Providers.Dto.Responses;

namespace dor-cytech-poc1.Tests.System.Infrastructure.Providers.Interfaces
{
    /// <summary>
    /// STS OAuth API provider interface for system tests.
    /// Used to generate access tokens for test users.
    /// </summary>
    public interface IStsOAuthApiProvider : IRestProvider
    {
        /// <summary>
        /// Creates an access token for the specified user.
        /// </summary>
        Task<CreateAccessTokenResponse> CreateAccessTokenAsync(CreateAccessTokenRequest request);
    }
}
