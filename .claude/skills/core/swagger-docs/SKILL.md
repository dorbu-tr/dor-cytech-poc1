<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/core/swagger-docs/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
---
name: swagger-docs
description: OpenAPI 3.0 documentation patterns including XML comments, ProducesResponseType attributes, and business-perspective descriptions. Use when implementing Swagger docs, OpenAPI specification, XML summary comments, API documentation, or adding response type annotations to controllers and DTOs.
---

# Swagger/OpenAPI Documentation Patterns

## OpenAPI Requirements
- Provide OpenAPI 3.0+ specification
- Keep spec in sync with implementation
- Use spec as source of truth for contracts

## Documentation Perspective

ALL descriptions MUST be from a **business perspective**:

| Correct (Business) | FORBIDDEN (Implementation) |
|--------------------|---------------------------|
| "Customer's preferred trading currency" | "Currency code stored in user table" |
| "Unique instrument identifier used across trading" | "Auto-incrementing primary key from DB" |

## Controller Documentation

Every controller MUST have:
- `[ApiController]`, `[Produces("application/json")]`
- `/// <summary>` describing domain/responsibility

```csharp
/// <summary>
/// Controller for order management operations.
/// </summary>
[Route("api/v1/orders")]
[ApiController]
[Produces("application/json")]
public sealed class OrdersController : ControllerBase
```

## Action Method Documentation

Every action MUST have:
- `/// <summary>` -- one-line description
- `/// <remarks>` -- detailed explanation, business rules
- `/// <param name="...">` -- for each parameter
- `/// <returns>` -- return description
- `/// <response code="XXX">` -- for EACH status code
- `[ProducesResponseType]` attributes

```csharp
/// <summary>
/// Gets aggregated product detail data for a specific item.
/// </summary>
/// <remarks>
/// Returns product detail including balance, rate, metadata, and transactions.
/// </remarks>
/// <param name="request">Request with itemId and options.</param>
/// <returns>Aggregated product detail data.</returns>
/// <response code="200">Product detail data.</response>
/// <response code="400">Invalid itemId.</response>
/// <response code="401">Missing or invalid authorization.</response>
/// <response code="404">Item not found.</response>
[HttpGet("{itemId}")]
[ProducesResponseType(typeof(ProductDetailResponse), (int)HttpStatusCode.OK)]
[ProducesResponseType((int)HttpStatusCode.BadRequest)]
[ProducesResponseType((int)HttpStatusCode.NotFound)]
public async Task<IActionResult> GetProductDetailAsync(GetProductDetailRequest request)
```

## Request DTO Documentation

Every property appearing in Swagger MUST have:
- `/// <summary>` -- clear description
- `/// <example>` -- example value

```csharp
public sealed class GetProductDetailRequest
{
    /// <summary>
    /// The item ID of the product.
    /// </summary>
    /// <example>100001</example>
    [FromRoute(Name = "itemId")]
    public int ItemId { get; set; }
}
```

## Response DTO Documentation

Every response property MUST have XML documentation:
```csharp
/// <summary>
/// Response containing product detail data.
/// </summary>
public sealed class ProductDetailResponse
{
    /// <summary>
    /// Current rate in user's fiat currency.
    /// </summary>
    /// <example>42350.50</example>
    public decimal Rate { get; set; }
}
```

## Enum Documentation

Every enum value MUST have XML documentation:
```csharp
/// <summary>
/// Instrument types available for trading.
/// </summary>
public enum InstrumentType
{
    /// <summary>Equity shares of a company.</summary>
    Stock = 1,
    /// <summary>Exchange-traded fund.</summary>
    Etf = 2
}
```

## Schema Requirements
- All properties must have types and descriptions
- Nullable properties clearly marked
- Date-time in ISO 8601 UTC format
- Decimal precision documented

## Project Configuration
Enable XML documentation generation in `.csproj`:
```xml
<PropertyGroup>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <NoWarn>$(NoWarn);1591</NoWarn>
</PropertyGroup>
```

Configure SwaggerGen to include XML docs in your bootstrapper.

## Backend-to-Backend Endpoint Documentation

For endpoints using backend auth (API key), document the API key header requirement:

```csharp
/// <summary>
/// Gets KYC fields for a specific user (backend-to-backend, API key required).
/// </summary>
/// <remarks>
/// Requires X-Api-Key header with a valid admin secret key.
/// This endpoint is intended for backend service-to-service calls.
/// </remarks>
[HttpGet("kyc-fields")]
[BackendAuth]
[ProducesResponseType(typeof(GetKycFieldsResponse), (int)HttpStatusCode.OK)]
[ProducesResponseType((int)HttpStatusCode.Unauthorized)]
public async Task<IActionResult> GetKycFields(GetKycFieldsRequest request)
```

Note: Backend auth endpoints return 401 for auth failures (not 403). Document this status code.

## Anti-Patterns
| FORBIDDEN | Correct |
|-----------|---------|
| Missing XML docs | Complete XML docs on all public types |
| Implementation details in descriptions | Business perspective only |
| Missing `[ProducesResponseType]` | All possible status codes listed |
| Missing `/// <example>` | Examples on all request/response properties |
| Missing `[Produces("application/json")]` | Always on controller class |
