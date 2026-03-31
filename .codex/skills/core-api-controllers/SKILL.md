---
name: "core-api-controllers"
description: "API controller implementation patterns including request validation, Internalize/Externalize mapping, and the single-request-object method flow. Use when implementing controllers, request/response DTOs, request validation, mapping request to parameters, or mapping results to responses."
metadata:
  short-description: "API controller implementation patterns including request validation, Internalize/Externalize mapping, and the single-request-object method flow. Use when implementing controllers, request/response DTOs, request validation, mapping request to parameters, or mapping results to responses."
---

<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/core/api-controllers/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->
# API Controller Patterns

## Controller Method Flow (NON-NEGOTIABLE)

Every controller action follows this abstract flow:
1. **Validate** the incoming request (team-specific: manual `Validate()`, FluentValidation, etc.)
2. **Extract** user identity from authenticated request (if client-facing)
3. **Map** request to application parameters (Internalize or AutoMapper)
4. **Call** the application service
5. **Map** result to response (Externalize or AutoMapper)
6. **Return** the appropriate HTTP response

The specific validation and mapping approach is team-specific — see team skill `api-controllers`.

## Controller Naming
- Plural for collections: `OrdersController`, `UsersController`
- Singular for singletons: `ProfileController`, `ConfigurationController`
- Route: `[Route("api/v1/{resource}")]` — lowercase, kebab-case

## Internalize/Externalize Pattern (shared by infra + onboarding)

Extension methods that map between API DTOs and application DTOs:

**RequestExtensions.cs** (`Api/Extensions/`):
```csharp
public static GetProductDetailParameters Internalize(this GetProductDetailRequest request, int userId)
    => new(request.ItemId, userId, request.Currency);
```

**ResultExtensions.cs** (`Api/Extensions/`):
```csharp
public static ProductDetailResponse Externalize(this GetProductDetailResult result)
    => new(result);
```

Teams that use AutoMapper instead of manual mapping should see their team skill `api-controllers` for the alternative pattern.

## Binding Attributes

- `[FromRoute]`, `[FromQuery]` on DTO properties (NOT method parameters)
- `[FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)]` on Body property
- Never `[FromQuery]` or `[FromBody]` on the method parameter itself

## User Identity Rule
User identity NEVER in routes or query params for client-facing endpoints. Always extracted from the authenticated request context. Backend-to-backend endpoints do NOT have user identity from auth — the caller is a service.

## Backend-to-Backend Authentication Pattern

For endpoints called by backend services that authenticate with an API key instead of a client auth token, use a dedicated backend auth filter attribute instead of the client-facing auth attribute.

Key differences from client-facing endpoints:
- Backend auth filter attribute instead of client-facing auth attribute
- No user identity from auth — may come from route/query if needed
- No auth token forwarding pattern

## Parameterless GET Endpoints
No request DTO — create parameters directly:
```csharp
[HttpGet]
[ClientAuth]
public async Task<IActionResult> GetOrdersAsync()
{
    var authResult = Request.GetAuthenticatedUserId();
    var parameters = new GetOrdersParameters { UserId = authResult };
    var result = await _service.GetOrdersAsync(parameters);
    return Ok(result.Externalize());
}
```

## Request Default Values

Defaults MUST come from your configuration provider, NOT hardcoded.

## DELETE Endpoint Pattern

DELETE returns `NoContent()` (204). No response body.
```csharp
[HttpDelete("{resourceId}")]
[ClientAuth]
[ProducesResponseType((int)HttpStatusCode.NoContent)]
[ProducesResponseType((int)HttpStatusCode.NotFound)]
public async Task<IActionResult> DeleteResource(DeleteResourceRequest request)
{
    // validate + map
    await _service.DeleteResourceAsync(parameters);
    return NoContent();
}
```

## Namespace Alias Pattern

When both API and Infrastructure layers have DTOs with the same name, use namespace aliases:
```csharp
using ApiRequests = MyProject.Api.Dto.Requests;
using ProviderRequests = MyProject.Infrastructure.Providers.Dto.Requests.MyApi;
```

## ExternalizeAll() — Collection Extension Pattern

When converting a list of application-layer items to API-layer items, create an `ExternalizeAll()` extension:
```csharp
public static IReadOnlyList<ResourceItem> ExternalizeAll(this IEnumerable<ResourceData> items)
    => items.Select(ResourceItem.FromData).ToList();
```

## Created Response DTOs with Extra One-Time Fields

When a POST create response returns additional one-time fields (e.g., `ClientSecret`) that the base GET response does not include:
- The base `{Resource}Item` MUST be `class` (NOT `sealed class`) to allow inheritance
- Create a `Created{Resource}Item` class that **inherits from** the base `{Resource}Item`
- Use a generic `Externalize<T>()` extension method on the shared data type

### Created() Location Header Convention
- When a GET-by-ID endpoint exists: `return Created($"/api/v1/resources/{result.ResourceId}", response);`
- When no GET-by-ID endpoint exists: `return Created("", response);` is acceptable
- NEVER use `Ok()` for 201 Created responses

## File Organization
```
dor-cytech-poc1.Api/
  Controllers/          # Thin controllers
  Dto/Requests/         # Request DTOs
  Dto/Requests/Body/    # Request body classes (if separate)
  Dto/Responses/        # Top-level response DTOs ONLY
  Dto/Data/             # Nested complex objects used within responses (NOT suffixed with Response)
  Extensions/           # Mapping extensions (Internalize/Externalize or equivalent)
  Exceptions/           # Validation/auth exceptions
```

## Authentication Decision Guide

| Caller Type | Attribute | Header | User Identity Source |
|-------------|-----------|--------|---------------------|
| Client app (user) | Client-facing auth | Authorization token | From auth validation result |
| Backend service | Backend auth filter | API key header | Route/query param (if needed) |

A single controller CAN mix both patterns — some actions with client-facing auth, others with backend auth.
