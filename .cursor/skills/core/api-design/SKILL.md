---
name: api-design
description: REST API design conventions including routes, versioning, pagination, correlation headers, and breaking change policy. Use when designing API routes, REST conventions, URL structure, query parameters, pagination responses, caching headers, or planning breaking changes and deprecations.
---

# API Design Conventions

## REST Architectural Constraints

| Constraint | Requirement |
|------------|-------------|
| Stateless | Each request contains all needed information |
| Resource-based | Expose resources (nouns) not actions (verbs) |
| Standard HTTP methods | Use appropriate HTTP verbs |
| Cacheable | Define cacheability explicitly via headers |

## Route Pattern (MANDATORY)

```
api/v1/{resource}                      # List/Create
api/v1/{resource}/{id}                 # Get/Update/Delete
api/v1/{resource}/{id}/{sub-resource}  # Nested resources
```

### Route Naming Rules
- Lowercase for all segments: `api/v1/order-balances`
- Kebab-case for multi-word: `/market-hours`, `/overnight-fees`
- Plural nouns for collections: `/instruments`, `/orders`
- Path parameters for IDs: `api/v1/instruments/{instrumentId}`
- NO GCID/CID in routes for client-facing endpoints
- NO `[controller]` token
- NO verbs in URLs

## Versioning Strategy

URL-based: `/api/v1/`, `/api/v2/`
- Integer versions only
- Start with `v1` for all new APIs
- All APIs must be versioned

### Breaking vs Non-Breaking Changes

**Non-Breaking** (same version): Adding optional fields, new endpoints, new query params
**Breaking** (new version): Removing/renaming fields, changing types, making optional required

## Pagination Standards

### Cursor-based (RECOMMENDED for large datasets)
```json
{
  "results": [...],
  "pagination": { "pageSize": 50, "nextPageToken": "...", "hasNext": true }
}
```

### Offset-based (for smaller datasets)
```json
{
  "results": [...],
  "pagination": { "page": 3, "pageSize": 50, "totalItems": 200, "hasNext": true }
}
```

`hasNext` is ALWAYS required.

## Distributed Tracing

| Header | Direction | Description |
|--------|-----------|-------------|
| `X-Request-Id` | Client -> API -> Response | Unique request identifier |
| `X-Correlation-Id` | API -> Response | Auto-generated correlation |

## Query Parameters
- camelCase: `?instrumentId=123&settlementType=CFD`
- NOT snake_case

## Feature Flags via Headers
```
GET /api/v1/orders
X-API-Features: include-extended-metadata
```

## Deprecation Policy
1. T-6 months: Add `Sunset` header (RFC 8594), `Deprecation: true`
2. T-3 months: Log usage, notify consumers
3. T-0: Return `410 Gone`

## Standard HTTP Methods
| Method | Route | Purpose | Idempotent |
|--------|-------|---------|------------|
| GET | `api/v1/{resource}` | List | Yes |
| GET | `api/v1/{resource}/{id}` | Get single | Yes |
| POST | `api/v1/{resource}` | Create | No |
| PUT | `api/v1/{resource}/{id}` | Full update | Yes |
| PATCH | `api/v1/{resource}/{id}` | Partial update | No |
| DELETE | `api/v1/{resource}/{id}` | Delete | Yes |

## Health Endpoints (auto-provided)
`/api/ping`, `/api/healthcheck`, `/api/liveness`, `/api/readiness`, `/api/status`
All provided by your monitoring framework -- do NOT create custom health controllers.

## Authentication Methods

### Client-Facing Authentication (Default)
Standard for endpoints called by client applications (web, mobile):
- Apply a client-facing auth attribute on every controller action
- Client sends `Authorization` header with an authentication token
- User identity extracted from the validated auth result

### Backend-to-Backend Authentication
For endpoints called by other backend services that don't have a client auth token:
- Apply a backend auth filter attribute on controller action (instead of the client-facing attribute)
- Caller sends a dedicated header (e.g., `X-Api-Key`) with a configured secret key
- No user identity from auth -- if needed, it comes from route/query parameters
- API keys managed via your configuration provider (stored in secret vault)
- Each key has an associated `Service` name for audit/monitoring

### Mixed Controllers
A single controller CAN have both client-facing and backend-to-backend authenticated actions:
```
[Route("api/v1/orders")]
public class OrdersController : ControllerBase
{
    [HttpGet]
    [ClientAuth]                 // Client-facing: auth token
    public async Task<IActionResult> GetOrders(...)

    [HttpGet("summary")]
    [BackendAuth]                // Backend-to-backend: API key
    public async Task<IActionResult> GetOrdersSummary(...)
}
```

## Identifiers
Enum IDs allowed for internal APIs. Provide enumeration endpoints: `GET /api/v1/enums/{enum-type}`
