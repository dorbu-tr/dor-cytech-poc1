namespace dor-cytech-poc1.Api.Configuration;

public sealed class AuthorizationConfiguration
{
    public const string AuthorizationHeaderName = "Authorization";

    public string AppSecret { get; set; }
    public string ReadOnlyAppSecret { get; set; }
    public string ReadWriteAppSecret { get; set; }
}
