# eToro API Standards Compliance (Principle XIII)

All Trading APIs MUST comply with eToro API Development Standards (CTO-approved, January 2026).

## Table of Contents
- [Obligation Levels by API Tier](#obligation-levels-by-api-tier)
- [13.1 API Classification](#131-api-classification)
- [13.2 Versioning](#132-versioning-and-backward-compatibility)
- [13.3 Request/Response Envelopes](#133-requestresponse-envelope-standards)
- [13.4 Error Format](#134-error-response-format)
- [13.5 Distributed Tracing](#135-distributed-tracing-and-correlation)
- [13.6 Pagination](#136-pagination-standards)
- [13.7 Caching](#137-caching-and-cache-control)
- [13.8 Content Negotiation](#138-content-negotiation)
- [13.9 Security Headers](#139-security-headers)
- [13.10 Idempotency](#1310-idempotency)
- [13.11 Date-Time Formats](#1311-date-time-formats)
- [13.12 Query Parameters](#1312-query-parameter-naming)
- [13.13 Health Endpoints](#1313-health-check-endpoints)
- [13.14 OpenAPI Spec](#1314-openapi-specification-requirements)
- [13.15 Identifiers/Enums](#1315-identifiers-and-enumerations)
- [Compliance Checklist](#api-standards-compliance-checklist)

---

## Obligation Levels by API Tier

**MUST** = required, blocks deployment. **SHOULD** = recommended, tracked as tech debt.

| Requirement | Team | Internal | eToro Client | Public | Section |
|-------------|------|----------|--------------|--------|---------|
| API Classification declared | MUST | MUST | MUST | MUST | 13.1 |
| URL-based versioning | SHOULD | MUST | MUST | MUST | 13.2 |
| Deprecation policy (6 months) | -- | MUST | MUST | MUST | 13.2 |
| Standardized error format | SHOULD | MUST | MUST | MUST | 13.4 |
| Success envelope | -- | SHOULD | SHOULD | MUST | 13.3 |
| x-request-id / x-correlation-id | SHOULD | MUST | MUST | MUST | 13.5 |
| Pagination on collections | SHOULD | MUST | MUST | MUST | 13.6 |
| Cache-Control headers on GET | SHOULD | MUST | MUST | MUST | 13.7 |
| Security headers | SHOULD | MUST | MUST | MUST | 13.9 |
| Idempotency-Key (critical POST) | -- | SHOULD | MUST | MUST | 13.10 |
| ISO 8601 UTC date-times | MUST | MUST | MUST | MUST | 13.11 |
| camelCase query params | MUST | MUST | MUST | MUST | 13.12 |
| Health without auth | MUST | MUST | MUST | MUST | 13.13 |
| OpenAPI 3.0+ spec | SHOULD | MUST | MUST | MUST | 13.14 |
| OpenTelemetry integration | -- | SHOULD | SHOULD | SHOULD | 13.5 |
| ETag support | -- | SHOULD | SHOULD | SHOULD | 13.7 |
| CSV for reporting endpoints | -- | SHOULD | MUST | MUST | 13.8 |
| Meaningful enum strings | -- | -- | -- | MUST | 13.15 |
| Enum endpoints (when using IDs) | -- | MUST | MUST | -- | 13.15 |

---

## 13.1 API Classification

Every API MUST be classified before implementation:

| Tier | Purpose | Auth | Enum Handling |
|------|---------|------|---------------|
| **Team/Domain** | Within a specific team | Team-managed | Team discretion |
| **Internal** | Service-to-service across teams | API keys | IDs + enum endpoints |
| **eToro Client** | eToro apps (web/mobile) | OAuth2/Bearer | IDs + enum endpoints |
| **Public** | Third-party developers | API Keys | Meaningful strings only |

Document in OpenAPI:
```yaml
info:
  title: Trading Orders API
  x-api-classification: etoro-client
```

**Governance by Tier:**

| Aspect | Team | Internal | eToro Client | Public |
|--------|------|----------|--------------|--------|
| Deprecation Policy | None | 6 months | 6 months | 6 months |
| SLA Guarantees | None | None | Formal | Formal (published) |
| Rate Limiting | None | None | Per user | Per key (tiered) |
| Change Review | None | Team coordination | Review process | Review board |

---

## 13.2 Versioning and Backward Compatibility

URL-based versioning REQUIRED for Internal, eToro Client, Public:
```
/api/v1/orders
/api/v2/orders
```

**Breaking changes** (require new version): removing/renaming fields, changing types, making optional required, removing endpoints.

**Non-breaking** (same version OK): adding optional fields, new endpoints, new optional query params.

**Deprecation** (Internal+): T-6 months add `Sunset`/`Deprecation` headers -> T-3 months log usage -> T-0 return `410 Gone`.

---

## 13.3 Request/Response Envelope Standards

**GET**: Response body contains resource/collection directly. Pagination metadata in body, other metadata in headers.

**Paginated GET**:
```json
{
  "results": [],
  "pagination": { "nextPageToken": "...", "hasNext": true, "totalItems": 100 }
}
```

**POST/PUT/PATCH/DELETE** (MUST for Public, SHOULD for Internal/Client):
```json
{ "success": true, "data": { } }
{ "success": false, "error": { "code": "INVALID_INSTRUMENT", "message": "..." } }
```

Metadata in headers: `X-Request-Id`, `X-Timestamp`.

> Existing internal APIs using `return Ok(result)` per controller pattern are not in violation.

---

## 13.4 Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request parameters",
    "details": "Field 'quantity' must be greater than 0",
    "field": "quantity",
    "value": -5
  }
}
```

**HTTP Status Code Mapping:**

| Status | Usage |
|--------|-------|
| **200 OK** | Successful GET, PUT, PATCH, DELETE |
| **201 Created** | Successful POST creating new resource |
| **202 Accepted** | Request accepted for async processing |
| **204 No Content** | Successful DELETE with no response body |
| **400 Bad Request** | Invalid request syntax or validation failure |
| **401 Unauthorized** | Missing or invalid authentication |
| **403 Forbidden** | Authenticated but insufficient permissions |
| **404 Not Found** | Resource does not exist |
| **409 Conflict** | Conflict with current state (e.g., duplicate idempotency key) |
| **422 Unprocessable Entity** | Valid syntax but semantic errors |
| **429 Too Many Requests** | Rate limit exceeded |
| **500 Internal Server Error** | Unexpected server error |
| **503 Service Unavailable** | Service temporarily unavailable |

Error codes MUST be human-readable (`INVALID_INSTRUMENT`, `INSUFFICIENT_BALANCE`), documented in OpenAPI spec. NEVER expose stack traces in production.

---

## 13.5 Distributed Tracing and Correlation

| Header | Direction | Auto-generated? |
|--------|-----------|-----------------|
| `x-request-id` | Client -> API | No (client sends) |
| `x-correlation-id` | API -> Downstream | Yes (API generates if missing) |

Both MUST be propagated downstream, returned in response, and included in logs. If `x-correlation-id` is missing, API MUST generate one. If `x-request-id` is missing, API MUST NOT generate one.

**OpenTelemetry Integration:**
- Services SHOULD adopt OpenTelemetry for distributed tracing
- Map `x-correlation-id` to OpenTelemetry trace ID
- Map `x-request-id` to OpenTelemetry span attributes
- New services SHOULD implement OpenTelemetry from the start

```csharp
public class TracingMiddleware
{
    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        var requestId = context.Request.Headers["x-request-id"].FirstOrDefault();
        var correlationId = context.Request.Headers["x-correlation-id"].FirstOrDefault()
            ?? Guid.NewGuid().ToString();

        context.Response.OnStarting(() =>
        {
            if (!string.IsNullOrEmpty(requestId))
                context.Response.Headers["x-request-id"] = requestId;
            context.Response.Headers["x-correlation-id"] = correlationId;
            return Task.CompletedTask;
        });
        await next(context);
    }
}
```

---

## 13.6 Pagination Standards

**Cursor-based** (recommended for large/changing datasets):
```
GET /api/v1/orders?pageSize=50&pageToken=eyJsYXN0SWQiOjEyMzQ1fQ==
```
```json
{ "results": [], "pagination": { "pageSize": 50, "nextPageToken": "...", "hasNext": true } }
```

**Offset-based** (small stable datasets):
```
GET /api/v1/orders?page=3&pageSize=50
```
```json
{ "results": [], "pagination": { "page": 3, "pageSize": 50, "totalItems": 200, "totalPages": 4, "hasNext": true } }
```

`hasNext` MUST always be provided. Default/max `pageSize` MUST be documented.

---

## 13.7 Caching and Cache-Control

| Data Type | Cache-Control |
|-----------|--------------|
| Static reference | `public, max-age=86400, immutable` |
| Frequently updated | `public, max-age=60, must-revalidate` |
| User-specific | `private, max-age=300` |
| Sensitive | `private, no-store` |
| Volatile | `no-cache` |

Cacheable resources SHOULD support ETag + `304 Not Modified`.

**Caching Anti-Patterns:**
- No `Cache-Control` header (undefined behavior)
- Aggressive caching of dynamic data
- No caching for static reference data
- Inconsistent caching across similar endpoints

**OpenAPI Cache-Control declaration:**
```yaml
responses:
  '200':
    headers:
      Cache-Control:
        schema:
          type: string
        example: "public, max-age=3600"
```

---

## 13.8 Content Negotiation

JSON is default: `Content-Type: application/json; charset=utf-8`. CSV REQUIRED for reporting/bulk endpoints. Return `406 Not Acceptable` for unsupported formats.

---

## 13.9 Security Headers

All APIs MUST include:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
```

```csharp
app.Use(async (context, next) =>
{
    context.Response.Headers.Append("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Append("X-Frame-Options", "DENY");
    context.Response.Headers.Append("X-XSS-Protection", "1; mode=block");
    await next();
});
```

---

## 13.10 Idempotency

GET, PUT, DELETE are idempotent by nature. For POST/PATCH critical operations:
- eToro Client & Public: MUST accept `Idempotency-Key` header
- Internal: SHOULD accept `Idempotency-Key`
- Store keys 24h minimum, return `409 Conflict` on duplicate with different payload.

**Implementation Pattern:**
```csharp
[HttpPost]
public async Task<IActionResult> CreateOrder(
    [FromBody] CreateOrderRequest request,
    [FromHeader(Name = "Idempotency-Key")] string? idempotencyKey)
{
    if (!string.IsNullOrEmpty(idempotencyKey))
    {
        var existing = await _idempotencyService.GetExistingAsync(idempotencyKey);
        if (existing != null) return Ok(existing);
    }
    // Process order...
}
```

---

## 13.11 Date-Time Formats

All date-times MUST use ISO 8601 UTC: `2025-12-11T14:30:00Z`

When timezone context needed:
```json
{ "createdAt": "2025-12-11T14:30:00Z", "timezone": "America/New_York" }
```

---

## 13.12 Query Parameter Naming

MUST use camelCase:
```
✅ ?instrumentId=12345&settlementType=CFD
❌ ?instrument_id=12345&settlement_type=CFD
```

---

## 13.13 Health Check Endpoints

Trading framework provides `/ping` and `/api/status` (PRIMARY). Additionally SHOULD expose:
- `/liveness` -- process running (container restart decisions)
- `/readiness` -- ready for traffic (load balancer decisions)

Health endpoints MUST be without auth, not rate limited, respond < 1 second.

---

## 13.14 OpenAPI Specification Requirements

All APIs MUST provide OpenAPI 3.0+ spec. All endpoints MUST include: summary, description, parameter descriptions, all error responses. All fields MUST include: description, examples, constraints.

---

## 13.15 Identifiers and Enumerations

**Public APIs**: Meaningful strings only (`"stock"`, `"active"`).
**Internal/Client APIs**: May use numeric IDs but MUST expose `GET /api/v1/enums/{enum-type}` endpoints.

---

## API Standards Compliance Checklist

**MUST for all tiers:**
- [ ] API tier classification in OpenAPI spec (13.1)
- [ ] ISO 8601 UTC date-times (13.11)
- [ ] camelCase query params (13.12)
- [ ] Health endpoints without auth (13.13)
- [ ] JSON default content type (13.8)

**MUST for Internal, eToro Client, Public:**
- [ ] URL-based versioning (13.2)
- [ ] Standardized error format (13.4)
- [ ] x-request-id / x-correlation-id (13.5)
- [ ] Pagination on collections (13.6)
- [ ] Cache-Control headers on GET (13.7)
- [ ] Security headers (13.9)
- [ ] OpenAPI 3.0+ spec (13.14)

**MUST for eToro Client, Public:**
- [ ] Idempotency-Key for critical POST (13.10)

**MUST for Public only:**
- [ ] Success envelope on mutations (13.3)
- [ ] Enum values as strings (13.15)
