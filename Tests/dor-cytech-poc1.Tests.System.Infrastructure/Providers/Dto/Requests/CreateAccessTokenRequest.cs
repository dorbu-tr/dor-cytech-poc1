namespace dor-cytech-poc1.Tests.System.Infrastructure.Providers.Dto.Requests
{
    /// <summary>
    /// Request DTO for creating an access token via STS OAuth API.
    /// </summary>
    public sealed class CreateAccessTokenRequest
    {
        /// <summary>
        /// Global Customer ID.
        /// </summary>
        public int Gcid { get; init; }

        /// <summary>
        /// Application name for the token.
        /// </summary>
        public string ApplicationName { get; init; }

        /// <summary>
        /// Authorized scope IDs.
        /// </summary>
        public ISet<int> AuthorizedScopeIds { get; init; }

        /// <summary>
        /// Additional claims to include in the token.
        /// </summary>
        public IDictionary<string, string> AdditionalClaims { get; init; }

        /// <summary>
        /// Token expiration time in seconds.
        /// </summary>
        public int ExpiresInSeconds { get; init; }
    }
}
