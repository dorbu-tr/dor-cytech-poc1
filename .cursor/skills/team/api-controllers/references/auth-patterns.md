# Authentication & Authorization Patterns

## Table of Contents
- [AppSecret Pattern](#appsecret-pattern)
- [STS Pattern](#sts-pattern)
- [Anti-Patterns](#authentication-anti-patterns)

---

## AppSecret Pattern

Use for backend-to-backend: internal tools, service-to-service, background jobs, admin tools.

### Configuration Classes

**AuthorizationConfiguration** (`Application/Configuration/`):
```csharp
public class AuthorizationConfiguration
{
    public string ReadOnlyAppSecret { get; set; }
    public string ReadWriteAppSecret { get; set; }
    public const string AuthorizationHeaderName = "Authorization";
}
```

**Add to main config** (`Bootstrap/Configurations/{ServiceName}Configuration.cs`):
```csharp
public class {ServiceName}Configuration : IEnvironmentConfig
{
    public const string ConfigurationSection = "{ServiceName}";
    public AuthorizationConfiguration {ServiceName}AppSecret { get; set; }
}
```

**KeyVault config** (`Bootstrap/Configurations/{ServiceName}KeyVaultConfigurations.cs`):
```csharp
public class {ServiceName}KeyVaultConfigurations : KeyVaultConfigurationWithCcmLogin
{
    [ValueCensorLogicAll]
    [KeyVaultConfigurationOverride(
        {ServiceName}Configuration.ConfigurationSection,
        nameof({ServiceName}Configuration.{ServiceName}AppSecret),
        nameof({ServiceName}Configuration.{ServiceName}AppSecret.ReadOnlyAppSecret))]
    public string {ServiceName}ReadOnlyAppSecret { get; set; } = "ReadOnlyAppSecret";

    [ValueCensorLogicAll]
    [KeyVaultConfigurationOverride(
        {ServiceName}Configuration.ConfigurationSection,
        nameof({ServiceName}Configuration.{ServiceName}AppSecret),
        nameof({ServiceName}Configuration.{ServiceName}AppSecret.ReadWriteAppSecret))]
    public string {ServiceName}ReadWriteAppSecret { get; set; } = "ReadWriteAppSecret";
}
```

### Authorization Service

**Enum** (`Application/Authorization/AuthorizationLevel.cs`):
```csharp
public enum AuthorizationLevel { ReadOnly = 0, ReadWrite = 1 }
```

**Interface** (`Application/Authorization/IAuthorizationService.cs`):
```csharp
public interface IAuthorizationService
{
    Dictionary<string, AuthorizationLevel> GetAuthorizationLevels();
}
```

**Implementation** (`Application/Authorization/AuthorizationService.cs`):
```csharp
public class AuthorizationService : IAuthorizationService
{
    private readonly Dictionary<string, AuthorizationLevel> _authorizationLevels;

    public AuthorizationService(AuthorizationConfiguration configuration)
    {
        if (configuration == null) throw new ArgumentNullException(nameof(configuration));
        if (string.IsNullOrEmpty(configuration.ReadOnlyAppSecret) ||
            string.IsNullOrEmpty(configuration.ReadWriteAppSecret))
            throw new ArgumentException("Configuration properties cannot be null or empty");

        _authorizationLevels = new Dictionary<string, AuthorizationLevel>
        {
            { configuration.ReadOnlyAppSecret.ToLower(), AuthorizationLevel.ReadOnly },
            { configuration.ReadWriteAppSecret.ToLower(), AuthorizationLevel.ReadWrite }
        };
    }

    public Dictionary<string, AuthorizationLevel> GetAuthorizationLevels() => _authorizationLevels;
}
```

### AuthorizeLevel Attribute

`WebApi/Authorization/AuthorizeLevelAttribute.cs`:
```csharp
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false)]
public class AuthorizeLevelAttribute : TypeFilterAttribute
{
    public AuthorizeLevelAttribute(AuthorizationLevel requiredLevel)
        : base(typeof(AuthorizeLevelFilter))
    {
        Arguments = new object[] { requiredLevel };
    }

    private class AuthorizeLevelFilter : IAuthorizationFilter
    {
        private readonly string _appSecretHeaderName;
        private readonly AuthorizationLevel _requiredLevel;
        private readonly ILogger _logger;
        private readonly Dictionary<string, AuthorizationLevel> _authorizationLevels;

        public AuthorizeLevelFilter(
            AuthorizationLevel requiredLevel,
            IAuthorizationService authorizationService,
            ILogger logger)
        {
            _requiredLevel = requiredLevel;
            _logger = logger;
            _authorizationLevels = authorizationService.GetAuthorizationLevels();
            _appSecretHeaderName = AuthorizationConfiguration.AuthorizationHeaderName;
        }

        public void OnAuthorization(AuthorizationFilterContext context)
        {
            if (!ExtractRequestData(context.HttpContext, out var appSecret))
                throw new HeadersValidationException(
                    "Authorization header is required.", HttpStatusCode.BadRequest);

            if (!Authorize(appSecret))
                context.Result = new UnauthorizedResult();
        }

        private bool Authorize(string appSecret)
        {
            if (_authorizationLevels.TryGetValue(appSecret, out var matchedLevel))
                if (matchedLevel >= _requiredLevel) return true;
            return false;
        }

        private bool ExtractRequestData(HttpContext context, out string appSecret)
        {
            if (context.Request.Headers.TryGetValue(_appSecretHeaderName, out var appSecrets))
            {
                appSecret = appSecrets.FirstOrDefault()?.ToLower();
                return true;
            }
            appSecret = null;
            return false;
        }
    }
}
```

### HeadersValidationException

`WebApi/Headers/HeadersValidationException.cs`:
```csharp
public class HeadersValidationException : Exception
{
    public HttpStatusCode StatusCode { get; }
    public object ValidationDetails { get; }

    public HeadersValidationException(string message,
        HttpStatusCode statusCode = HttpStatusCode.BadRequest,
        object validationDetails = null) : base(message)
    {
        StatusCode = statusCode;
        ValidationDetails = validationDetails;
    }
}
```

### Controller Usage (AppSecret)

```csharp
[ApiController]
[Route("api/v1/instruments")]
[Produces("application/json")]
public sealed class InstrumentsController : ControllerBase
{
    [HttpGet]
    [AuthorizeLevel(AuthorizationLevel.ReadOnly)]
    public async Task<IActionResult> GetAll() { }

    [HttpPost]
    [AuthorizeLevel(AuthorizationLevel.ReadWrite)]
    public async Task<IActionResult> Create([FromBody] CreateInstrumentRequest request) { }
}
```

### Swagger Security Definition (AppSecret)

In `StartupExtensions.cs`:
```csharp
options.AddSecurityDefinition(AuthorizationConfiguration.AuthorizationHeaderName,
    new OpenApiSecurityScheme()
    {
        In = ParameterLocation.Header,
        Name = AuthorizationConfiguration.AuthorizationHeaderName,
        Type = SecuritySchemeType.ApiKey,
        Description = "Please enter AppSecret correlated to your application",
    });

options.AddSecurityRequirement(new OpenApiSecurityRequirement()
{
    {
        new OpenApiSecurityScheme
        {
            Reference = new OpenApiReference
            {
                Type = ReferenceType.SecurityScheme,
                Id = AuthorizationConfiguration.AuthorizationHeaderName
            }
        },
        Array.Empty<string>()
    }
});
```

---

## STS Pattern

Use for client-to-backend: user-facing APIs, mobile/web clients, endpoints requiring GCID.

### Required Packages

```xml
<PackageReference Include="eToro.Infrastructure.Auth.Sts" Version="[latest]" />
<PackageReference Include="eToro.Infrastructure.Auth.Sts.Mvc" Version="[latest]" />
```

### STS Configuration

**Interfaces** (`Application/Configuration/`):
```csharp
public interface IStsValidationApi { string BaseUrl { get; } int TimeoutInMs { get; } }
public interface IStsMetadataApi { string BaseUrl { get; } int TimeoutInMs { get; } }
public interface IStsRevocationApi { string BaseUrl { get; } }
public interface IStsRevocationEventsServiceBus { string ConnectionString { get; } }
```

**Bootstrap**:
```csharp
using eToro.Infrastructure.Auth.Sts.DependencyInjection.Extensions;

public static IServiceCollection AddStsAuthentication(this IServiceCollection services)
{
    services.AddSts();
    return services;
}
```

**Program.cs**:
```csharp
await app.UseStsAsync(options =>
{
    options.SetApplicationName("{ServiceName}");
    options.ConfigureValidationApiProvider(c =>
    {
        c.ValidationApiProviderUrlAccessor = () => configuration["Sts:ValidationApiUrl"];
        c.TimeoutInMsAccessor = () => int.Parse(configuration["Sts:ValidationApiTimeoutInMs"]);
    });
    options.ConfigureMetadataApiProvider(c =>
    {
        c.MetadataApiProviderUrlAccessor = () => configuration["Sts:MetadataApiUrl"];
        c.TimeoutInMsAccessor = () => int.Parse(configuration["Sts:MetadataApiTimeoutInMs"]);
    });
    options.ConfigureRevocationApiProvider(c =>
    {
        c.RevocationApiUrlAccessor = () => configuration["Sts:RevocationApiUrl"];
    });
});
```

### Controller Usage (STS)

```csharp
using eToro.Infrastructure.Auth.Sts.Mvc.Attributes;
using eToro.Infrastructure.Auth.Sts.Mvc.Extensions;

[ApiController]
[Route("api/v1/portfolio")]
[Produces("application/json")]
public sealed class PortfolioController : ControllerBase
{
    [HttpGet]
    [Authentication(PermissionId = 123)]
    public async Task<IActionResult> GetPortfolio()
    {
        var gcid = Request.GetAuthenticationResult().Gcid;
        var result = await _service.GetPortfolioAsync(gcid);
        return Ok(result);
    }

    [HttpPost("trade")]
    [Authentication(PermissionId = 456, ElevationLevelId = 2,
        UseTwoFactor = true, UseDigitalSignature = true)]
    public async Task<IActionResult> ExecuteTrade([FromBody] TradeRequest request)
    {
        var gcid = Request.GetAuthenticationResult().Gcid;
        return Ok(await _service.ExecuteTradeAsync(gcid, request));
    }
}
```

### STS CCM Configuration Keys

| Key | Example Value |
|-----|---------------|
| `StsValidationApiUrl` | `https://sts-validation.etoro.com` |
| `StsValidationApiTimeoutInMs` | `5000` |
| `StsMetadataApiUrl` | `https://sts-metadata.etoro.com` |
| `StsRevocationApiUrl` | `https://sts-revocation.etoro.com` |

### STS Mocking in Tests

```csharp
// In ComponentTestBootstrapper
protected override void AddSts(IServiceCollection services) => services.AddStsMock();

// In TestsBase
protected static ValidateResponse CreateValidateResponse(int gcid,
    Dictionary<string, string>? additionalClaims = null)
{
    var claims = new Dictionary<string, string> { ["gcid"] = gcid.ToString() };
    if (additionalClaims != null)
        foreach (var claim in additionalClaims) claims[claim.Key] = claim.Value;
    return new ValidateResponse { Gcid = gcid, Claims = claims };
}

// In Test API Provider
private static void AddMockedValidateResponseHeaderValue(
    RestRequest restRequest, ValidateResponse validateResponse)
{
    var value = Convert.ToBase64String(
        Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(validateResponse)));
    restRequest.Headers.Add(HeaderNames.Authorization, value);
    restRequest.Headers.Add("X-STS-MOCKED-VALIDATE-RESPONSE", value);
}
```

---

## STS Revocation Events (ServiceBus)

For real-time token revocation via Service Bus (recommended for user-facing APIs):

**Step 1: Add interface** in Bootstrap/Configurations:
```csharp
public interface IStsRevocationEventsServiceBus
{
    string ConnectionString { get; }
}
```

**Step 2: Configure in Program.cs** (add to the `UseStsAsync` call):
```csharp
// Revocation Events via ServiceBus (RECOMMENDED for user-facing APIs)
options.ConfigureRevocationEvents(c =>
{
    c.ServiceBusConnectionStringAccessor = () =>
        configuration["Sts:RevocationEventsConnectionString"];
});
```

**CCM keys required:**

| Key | Description |
|-----|-------------|
| `Sts:RevocationEventsConnectionString` | Service Bus connection string for revocation events |
| `Sts:MetadataApiTimeoutInMs` | Timeout for STS metadata API calls |

---

## Authentication Anti-Patterns

- DO NOT use AppSecret for user-facing APIs (use STS)
- DO NOT use STS for service-to-service calls (use AppSecret)
- DO NOT hardcode AppSecrets (use KeyVault)
- DO NOT miss `[ValueCensorLogicAll]` on secret properties
- DO NOT log AppSecrets or tokens
- DO NOT skip authentication on production endpoints
- DO NOT mix both auth patterns on the same controller
