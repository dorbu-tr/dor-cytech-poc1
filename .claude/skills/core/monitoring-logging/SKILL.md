<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/core/monitoring-logging/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
---
name: monitoring-logging
description: Monitoring wrapper and logging discipline patterns including sensitive data annotations and PII protection. Use when implementing MonitorWrapper, observability, SensitiveData attributes, structured logging, metrics, or monitoring discipline on async service methods.
---

# Monitoring & Logging Patterns

## Monitoring Wrapper Pattern

Services MUST use a monitoring wrapper abstraction (NOT the raw monitor interface directly).

### Field Declaration
```csharp
private readonly IMonitorWrapper _monitorWrapper; // wrapper abstraction
```

### Constructor Pattern
The raw monitor dependency MUST be the **LAST** parameter:
```csharp
public {Feature}Service(
    I{ApiName}ApiProvider {apiName}ApiProvider,
    IConfigurationProvider configurationProvider,
    IMonitor monitor)  // LAST parameter
{
    _{apiName}ApiProvider = {apiName}ApiProvider;
    _configurationProvider = configurationProvider;
    _monitorWrapper = CreateMonitorWrapper(monitor, nameof({Feature}Service));
}
```

### Method Wrapping
Every public async method MUST be wrapped with the monitoring wrapper. Always use the monitor data parameter (NEVER discard with `_`):
```csharp
public async Task<MethodResult> MethodAsync(MethodParameters parameters)
{
    return await _monitorWrapper.ExecuteActionAsync(async monitorData =>
    {
        var result = // ... business logic ...

        monitorData.Logs.ResourceId = result.ResourceId;
        monitorData.Logs.ItemCount = result.Items.Count;

        return result;
    }, new { parameters.ResourceId }, catchExceptions: false);
}
```

### Investigative Logging (MANDATORY)
Write **specific scalar fields** to monitor data that help investigate the flow in production logs.

**MUST log (scalar fields only):**
- Collection counts: `monitorData.Logs.ResourceCount = resources.Count`
- Key identifiers: `monitorData.Logs.CreatedResourceId = result.ResourceId`
- Cache hit/miss: `monitorData.Logs.CacheHit = cache != null`
- Lookup outcomes: `monitorData.Logs.UserFound = user != null`
- Request charges (DB queries): `monitorData.Logs.RequestCharge = response.RequestCharge`
- Status/outcome: `monitorData.Logs.Status = result.Status`

**NEVER log:**
- Entire result objects -- they may contain large nested objects or collections that bloat logs
- Large collections (raw list items) -- log the count instead
- Full request/response bodies from external APIs
- Sensitive data (passwords, tokens, PII without proper annotations)

### Component Type Selection
| Class Type | Component Type |
|------------|---------------|
| Application Services | Service |
| Jobs / Cache Loaders | Job |
| REST Providers | Handled by provider base class |
| Controllers | Handled by MVC monitor middleware |

### Sync vs Async Monitoring
Choose the correct variant based on whether the method body contains async I/O:

**Synchronous** -- cache reads, in-memory lookups, computations (no await):
Use `ExecuteAction` (sync). Drop `async`/`Task` from signature and `Async` suffix from method name.

**Asynchronous** -- provider calls, database queries, HTTP requests (has await):
Use `ExecuteActionAsync`. Method signature is `async Task<T>`.

**Rule**: If the lambda body has NO `await`, use the sync variant. If it has `await`, use the async variant.

## Sensitive Data Annotation Pattern

**Rule: PII -> Mask, Secrets -> Hash. No exceptions.**

Annotate DTO properties with a sensitive data attribute specifying the protection action:

### Classification Table

| Category | Action | Properties |
|----------|--------|------------|
| PII - Identity | `Mask` | email, phone, firstName, lastName, address |
| PII - Government IDs | `Mask` | ssn, nationalId, passportNumber |
| PII - Financial | `Mask` | creditCard, bankAccount, iban |
| Secrets - Auth | `Hash` | password, apiKey, clientSecret |
| Secrets - Tokens | `Hash` | accessToken, refreshToken, sessionToken |
| Secrets - Crypto | `Hash` | encryptionKey, privateKey, signingKey |

## Logging Discipline

- During development: Add diagnostic logs
- At phase end: Clean up for production
- NEVER log sensitive data -- use sensitive data annotations
- Structured logging with contextual properties
- Log levels: Debug (dev), Info (production events), Warn (recoverable), Error (failures)
- No string interpolation in log message templates

## Application Exception Pattern

Handled exceptions should map to HTTP status codes and be caught by the monitoring middleware.

### Rules:
- Error codes MUST be **PascalCase** (e.g., `"ResourceNotFound"`) -- NEVER `"RESOURCE_NOT_FOUND"`
- Messages MUST be **static strings** (e.g., `"Resource not found"`) -- NEVER embed data like `$"Resource {id} not found"`
- Contextual data goes in `IDictionary<string, object> data` parameter
- Constructor accepts `IDictionary<string, object> data = null`

### Correct Pattern:
```csharp
public sealed class ApplicationNotFoundException : MonitorHandledException
{
    public ApplicationNotFoundException(IDictionary<string, object> data = null)
        : base("Application not found", HttpStatusCode.NotFound, "ApplicationNotFound", data, Level.Warn)
    {
    }
}

// Throwing with contextual data:
throw new ApplicationNotFoundException(new Dictionary<string, object> { ["ClientId"] = clientId });
```
