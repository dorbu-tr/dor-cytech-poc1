namespace dor-cytech-poc1.Tests.System.Infrastructure.Providers.Dto.Responses
{
    /// <summary>
    /// Response DTO for creating an access token via STS OAuth API.
    /// </summary>
    public sealed class CreateAccessTokenResponse
    {
        /// <summary>
        /// Token details.
        /// </summary>
        public TokenDetails Token { get; set; }
    }

    /// <summary>
    /// Token details from STS OAuth API.
    /// </summary>
    public sealed class TokenDetails
    {
        /// <summary>
        /// JWT access token.
        /// </summary>
        public string Jwt { get; set; }

        /// <summary>
        /// Token expiration in milliseconds.
        /// </summary>
        public long ExpiresInMs { get; set; }
    }
}
