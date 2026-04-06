# Swagger/OpenAPI Documentation Patterns

## Swagger Configuration

```csharp
// In Bootstrap
services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "{ServiceName} API",
        Version = "v1",
        Description = "API for trading operations management"
    });

    // Include XML comments
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    options.IncludeXmlComments(xmlPath);
});

// In WebApi Program.cs (non-production only)
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
```

**Enable XML docs in .csproj**:
```xml
<PropertyGroup>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <NoWarn>$(NoWarn);1591</NoWarn>
</PropertyGroup>
```

## Controller Documentation Requirements

Every controller MUST have `[ApiController]`, `[Produces("application/json")]`, and `/// <summary>`:

```csharp
/// <summary>
/// Controller for instrument configuration management.
/// Provides endpoints to retrieve and update instrument settings.
/// </summary>
[Route("api/v1/instruments")]
[ApiController]
[Produces("application/json")]
public sealed class InstrumentsController : ControllerBase
```

## Action Method Documentation

Every action MUST have: `<summary>`, `<remarks>`, `<param>`, `<returns>`, `<response code>`, and `[ProducesResponseType]`:

```csharp
/// <summary>Gets instrument configuration by ID.</summary>
/// <remarks>
/// Returns comprehensive instrument configuration including:
/// - Instrument metadata (name, symbol, type)
/// - Fee configuration
/// - Margin settings
/// </remarks>
/// <param name="instrumentId">The instrument ID to retrieve.</param>
/// <returns>Instrument configuration data.</returns>
/// <response code="200">Returns the instrument configuration.</response>
/// <response code="400">Invalid instrumentId.</response>
/// <response code="404">Instrument not found.</response>
[HttpGet("{instrumentId}")]
[ProducesResponseType(typeof(InstrumentResponse), (int)HttpStatusCode.OK)]
[ProducesResponseType((int)HttpStatusCode.BadRequest)]
[ProducesResponseType((int)HttpStatusCode.NotFound)]
public async Task<IActionResult> GetById([FromRoute] int instrumentId)
```

## Request DTO Documentation

Every property MUST have `<summary>` and `<example>`:

```csharp
/// <summary>Request to get instrument details.</summary>
public sealed class GetInstrumentRequest
{
    /// <summary>The instrument ID to retrieve.</summary>
    /// <example>1001</example>
    [FromRoute(Name = "instrumentId")]
    public int InstrumentId { get; set; }

    /// <summary>Whether to include fee configuration.</summary>
    /// <example>true</example>
    [FromQuery(Name = "includeFees")]
    public bool IncludeFees { get; set; }
}
```

## Response DTO Documentation

```csharp
/// <summary>Response containing instrument configuration data.</summary>
public sealed class InstrumentResponse
{
    /// <summary>The unique instrument identifier.</summary>
    /// <example>1001</example>
    public int InstrumentId { get; set; }

    /// <summary>The display name of the instrument.</summary>
    /// <example>Apple Inc.</example>
    public string Name { get; set; }

    /// <summary>Fee configuration, or null if not requested.</summary>
    public FeeConfigDto FeeConfig { get; set; }
}
```
