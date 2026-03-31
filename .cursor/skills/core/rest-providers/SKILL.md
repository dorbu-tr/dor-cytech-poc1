---
name: rest-providers
description: REST provider architecture principles covering resilience patterns, health commands, provider DTOs, and circuit breaker requirements. Use when implementing REST providers, external API integrations, resilience patterns, or health commands. Team-specific implementation details live in the team rest-provider skill.
---

# REST Provider Principles

## Provider Resilience (NON-NEGOTIABLE)

All REST providers calling external APIs MUST implement resilience patterns (circuit breaker, retry, timeout). The specific base class or library (PolicyRestProviderBase, Polly ResiliencePipeline, etc.) is team-specific — see team skill `rest-provider`.

## Provider Registration

Providers MUST be registered using your team's prescribed pattern. See team skill `rest-provider` for the specific registration method.

## Bootstrapper Method Separation (NON-NEGOTIABLE)

The Bootstrapper has separate registration methods. Each type MUST go in its correct method:
- `RegisterServices(services)` -- Application services
- `RegisterProviders(services)` -- REST providers ONLY
- `RegisterRepositories(services)` -- Data repositories
- `RegisterJobs(services)` -- Cache loader jobs

**FORBIDDEN:** Registering jobs inside `RegisterProviders()`. Jobs go in `RegisterJobs()`.

## Provider Organization

- **One provider per external API** -- all HTTP methods in same class
- Provider naming: `I{ApiName}ApiProvider` / `{ApiName}ApiProvider`
- **FORBIDDEN:** `IPaymentServiceProvider`, `IPaymentProvider` (must end with `ApiProvider`)

## Provider DTO Naming

- `{Operation}{Resource}Request` / `{Operation}{Resource}Response` -- domain-specific names, NO generic prefixes
- CORRECT: `UpdateApplicationRequest`, `GetUserDetailsResponse`, `CreateOrderRequest`
- WRONG: `ProviderUpdateRequest`, `InfraGetResponse`, `ApiProviderRequest`
- Organized in subfolders by API:
```
Infrastructure/Providers/Dto/
  Requests/{ApiName}/
    Get{Resource}Request.cs
  Responses/{ApiName}/
    Get{Resource}Response.cs
```

## Provider Response DTO Minimalism (NON-NEGOTIABLE)

Provider response DTOs MUST contain **only the fields your service actually uses**. Do NOT mirror the full upstream API response. JSON deserialization silently ignores unmapped fields -- unused properties are dead code.

## Provider Single Responsibility

- Providers make SINGLE API calls only
- Pagination loops belong in Jobs/Services (Application layer)
- Business logic belongs in Application services

## Custom Exceptions Pattern

- **Infrastructure layer** exceptions inherit from a base exception class appropriate to your team's monitoring library
- **Application layer** exceptions inherit from a handled exception base class (maps to HTTP status codes)
- Pattern: Provider throws infrastructure exception -> Service catches -> converts to handled exception with correct HTTP status code

## Authorization Header Forwarding (NON-NEGOTIABLE)

**FORBIDDEN**: Automatic header forwarding middleware. When a provider needs to call a downstream API with the user's authorization, the provider MUST **explicitly receive the Authorization token** as a parameter and set it on the request headers.

**How it flows**: Controller extracts token from authenticated request -> passes to service -> service passes to provider method.

## API Key Authentication for Provider Calls (Backend-to-Backend)

When your provider calls a downstream API using an API key (not a user token), build headers internally from configuration.
