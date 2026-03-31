# Research: Trading Positions API

**Branch**: `001-trading-positions-api` | **Date**: 2026-03-31

## Research Summary

All NEEDS CLARIFICATION items from the Technical Context have been resolved via API Discovery MCP, NuGet audit, and constitution review. Below are the consolidated findings and decisions.

---

## 1. Upstream API Discovery

### Decision: Both upstream APIs live in the `trading-api` service

The Positions API and Instruments API are both served by the **same upstream service** (`trading-api`).

- **Integration**: `http://int-tapi-real.dev.local/`
- **Staging**: `http://stg-tapi-real.dev.local/`
- **Production**: `http://trade-real.api/`

Despite being the same service, we implement **two separate providers** (`PositionsApiProvider` and `InstrumentsApiProvider`) for:
- Independent circuit breakers and resilience pipelines
- Separation of concerns (STS-authenticated vs. public endpoints)
- Independent health checks
- Future-proofing if these APIs are split into separate services

---

### 1.1 Positions API — Discovered Endpoints

**Repository**: `trading-api` | **Domain**: Trading

#### GET /positions/private — List all open positions

| Parameter | Location | Type | Required | Description |
|-----------|----------|------|----------|-------------|
| Authorization | header | string | Yes | Raw STS token (NO 'Bearer' prefix) |
| ApplicationIdentifier | header | string | Yes | App identifier for STS auth |
| ApplicationVersion | header | string | Yes | App version for STS auth |
| AccountType | header | string | Yes | `Real` or `Demo` |

**Response** (`GetPositionsResponse`):
```json
{
  "Positions": [
    {
      "PositionID": 12345678,
      "CID": 1234567,
      "OpenDateTime": "2026-01-15T10:30:00Z",
      "OpenRate": 150.25,
      "InstrumentID": 1001,
      "IsBuy": true,
      "TakeProfitRate": 160.00,
      "StopLossRate": 140.00,
      "Amount": 1000.00,
      "Leverage": 5,
      "Units": 6.65,
      "TotalFees": -2.50,
      "InitialAmountInDollars": 1000.00,
      "IsTslEnabled": false,
      "IsSettled": false,
      "InitialUnits": 6.65,
      "SettlementTypeID": 0,
      "OpenConversionRate": 1.0,
      "LotCount": 0.0
    }
  ]
}
```

**Key observations**:
- Returns ALL open positions for the authenticated user (no server-side pagination)
- Auth: STS token pass-through (user's own token)
- Position ownership is inherent — the STS token scopes to the user's positions
- No "get single position by ID" endpoint — we filter from the full list

#### DELETE /positions/{positionId} — Close a position

| Parameter | Location | Type | Required | Description |
|-----------|----------|------|----------|-------------|
| positionId | path | int64 | Yes | Position ID to close |
| Authorization | header | string | Yes | Raw STS token |
| ApplicationIdentifier | header | string | Yes | App identifier |
| ApplicationVersion | header | string | Yes | App version |
| AccountType | header | string | Yes | `Real` or `Demo` |

**Request Body** (optional):
```json
{
  "ViewRateContext": { ... },
  "InstrumentID": 1001,
  "ExternalOperationType": 0,
  "ExternalOperationData": "",
  "ReferenceID": ""
}
```

**Response** (`CreateOrderForCloseMultipleResponse`):
```json
{
  "Token": "guid-tracking-token",
  "OrderForClose": {
    "OrderID": 999,
    "OrderType": 1,
    "StatusID": 0,
    "CID": 1234567,
    "OpenDateTime": "2026-03-31T12:00:00Z",
    "InstrumentID": 1001,
    "PendingClosePositionIDs": [12345678]
  }
}
```

**Key observations**:
- Uses DELETE method (not POST) on upstream — our service wraps this as `POST /api/v1/positions/{positionId}/close`
- Returns an async tracking token
- The `ClosePositionRequest` body is optional and supports `ViewRateContext` for rate specification
- Our service simplifies this by accepting only an optional `closeReason` and translating it

---

### 1.2 Instruments API — Discovered Endpoints

**Repository**: `trading-api` | **Domain**: Trading

#### GET /v2/instruments/{instrumentId} — Get instrument data

| Parameter | Location | Type | Required | Description |
|-----------|----------|------|----------|-------------|
| instrumentId | path | integer | Yes | Instrument ID |
| instrumentDataFilters | query | array[string] | No | Data filters: All, TradingData, Activity, Rates, etc. |

**Response** (`GetSingleInstrumentDataResponse`):
```json
{
  "Instrument": {
    "InstrumentID": 1001,
    "TypeID": 5,
    "IsVisible": true,
    "IsDelisted": false,
    "AllowClosePosition": true,
    "AllowManualTrading": true,
    "Precision": 2,
    "DefaultLeverage": 5,
    "Leverages": [1, 2, 5, 10]
  },
  "InstrumentActivityState": true,
  "Rate": {
    "InstrumentID": 1001,
    "Ask": 151.00,
    "Bid": 150.50,
    "LastExecution": 150.75
  }
}
```

**Key observations**:
- Public endpoint — no authentication required
- Rich response with many fields; we only extract what we need for enrichment (InstrumentID, TypeID, name-related fields)
- The Instrument object does NOT contain a human-readable "name" or "symbol" field
- For display names, we'd need a separate data source (not available in trading-api)

**Decision**: For enrichment, we use `InstrumentID`, `TypeID`, `IsDelisted`, `IsVisible`, `AllowClosePosition` from the Instrument response. The spec's requirement for "instrument name, symbol, type" will map to: `instrumentId`, `typeId`, and `isActive` (derived from `IsVisible` and `!IsDelisted`). Human-readable names are not available from this API in the POC.

---

## 2. Authentication Model

### Decision: STS token pass-through for Positions API, no auth for Instruments API

| Upstream API | Auth Method | Rationale |
|-------------|------------|-----------|
| Positions API | STS pass-through | Positions endpoints use STS auth and inherently scope to the authenticated user. This is simpler and more secure than using AppSecret + CID. |
| Instruments API | None (public) | The `/v2/instruments/{instrumentId}` endpoint requires no authentication. |

**Spec reconciliation**: NFR-006 states "API key authentication" for upstream calls. However, the discovered positions endpoints use STS tokens, not API keys. The admin-level endpoints (e.g., `DELETE /positions/byrate/{positionId}`) use AppSecret but require explicit CID. For a client-facing aggregator, STS pass-through is the correct pattern — it ensures the user can only access their own positions without our service needing to enforce ownership.

**Implementation**: The `PositionsApiProvider` forwards the user's STS token (and ApplicationIdentifier/ApplicationVersion/AccountType headers) from the incoming request context.

---

## 3. Pagination Strategy

### Decision: Client-side cursor-based pagination over the full upstream response

The upstream `GET /positions/private` returns ALL open positions with no server-side pagination. Our service implements cursor-based pagination on top:

- **Cursor encoding**: Base64-encoded offset (position index in the sorted list)
- **Default page size**: 20 (configurable via CCM)
- **Sort**: By `OpenDateTime` descending (newest first)
- **hasNext**: Required per constitution — derived from whether more items exist beyond the current page

**Rationale**: The upstream API returns all positions in a single call. For most retail traders, position counts are small (< 100). Implementing client-side pagination avoids complexity while meeting the API contract.

**Alternatives considered**:
- Server-side cursor from upstream: Not available (upstream returns full list)
- Offset-based pagination: Rejected — cursor-based is recommended by constitution for large datasets

---

## 4. Get Position by ID Strategy

### Decision: Filter from the full positions list

There is no dedicated "get position by ID" upstream endpoint. Implementation approach:

1. Call `GET /positions/private` to get all positions
2. Find the position with matching `PositionID`
3. Return 404 if not found (covers both "doesn't exist" and "not owned by this user")
4. Enrich with instrument data from `GET /v2/instruments/{instrumentId}`

**Performance note**: This means every detail request fetches all positions. For the POC this is acceptable. A production optimization would cache the positions list briefly (e.g., 5 seconds) per user.

---

## 5. Close Position — Request Mapping

### Decision: Map our simplified close request to the upstream DELETE

| Our service | Upstream |
|------------|----------|
| `POST /api/v1/positions/{positionId}/close` | `DELETE /positions/{positionId}` |
| Optional `closeReason` (enum) in body | Not directly mapped — stored as metadata via `ExternalOperationData` |
| STS token from client | Passed through to upstream |

The `closeReason` enum (UserRequested, StopLoss, TakeProfit, MarginCall, Other) is a convenience for our API consumers. We map it to `ExternalOperationData` in the upstream request body for traceability.

---

## 6. Graceful Degradation — Instruments API

### Decision: Return positions without instrument enrichment when Instruments API is down

Per NFR-004:
- If the Instruments API call fails (timeout, circuit open, error), the position response still returns
- Instrument fields (`instrumentTypeId`, `isActive`) will be null/omitted
- The circuit breaker for Instruments API operates independently of Positions API
- A warning is logged when degradation occurs

---

## 7. Resilience Configuration

### Decision: Per-provider Polly resilience pipelines

| Provider | Timeout | Retries | Backoff | Circuit Breaker |
|----------|---------|---------|---------|-----------------|
| Positions API | 2000ms | 2 | Exponential with jitter | 5 failures in 30s → 30s break |
| Instruments API | 1000ms | 2 | Exponential with jitter | 5 failures in 30s → 30s break |

These values come from the spec (edge cases section) and are configurable via CCM.

Each provider gets its own `ResiliencePipeline` registered in DI — NOT a shared pipeline. This ensures the Instruments API circuit breaker opening does not affect Positions API calls.

---

## 8. NuGet Dependencies — Final Decision

### Packages to ADD to Infrastructure .csproj:
- None needed — `Microsoft.Extensions.Http` and `Polly`/`Polly.Extensions` already present

### Packages to ADD to Api .csproj:
- `eToro.Trading.Framework.Metrics` (for IMetrics in service layer) — needs to be added to Application .csproj

### Packages to REMOVE (not needed for aggregator):
- `eToro.Trading.Sql.DbAccess` — from Infrastructure .csproj
- `eToro.Trading.Sql.Persistors` — from Infrastructure .csproj
- `eToro.Trading.Domain.Repositories` — from Infrastructure and Domain .csproj
- `eToro.Trading.Infrastructure.Repositories` — from Infrastructure .csproj
- `Scrutor` — from Infrastructure .csproj (no cached repository decoration needed)

---

## 9. Configuration Structure

### Decision: CCM-based configuration with sub-configurations

```
ServiceConfiguration (CCM root)
├── PositionsApiConfig
│   ├── BaseUrl: string
│   ├── TimeoutMs: int (2000)
│   ├── HealthCheckUrl: string
│   └── RetryCount: int (2)
├── InstrumentsApiConfig
│   ├── BaseUrl: string
│   ├── TimeoutMs: int (1000)
│   ├── HealthCheckUrl: string
│   └── RetryCount: int (2)
├── PaginationConfig
│   ├── DefaultPageSize: int (20)
│   └── MaxPageSize: int (100)
├── AppSecretConfig
│   └── AppSecret: string (from KeyVault)
├── StsConfig
│   ├── ApplicationIdentifier: string
│   └── ApplicationVersion: string
└── HealthCheckCacheResultInSeconds: int (30)
```

---

## 10. Service Architecture Pattern

### Decision: Follow trading-data-api (Aggregator) pattern

- **No database** — pure API aggregation
- **IHttpClientFactory** with typed clients for both providers
- **Polly v8** ResiliencePipeline per provider (retry + timeout + circuit breaker)
- **Static bootstrapper** pattern (single-API, no dual-API needed)
- **Framework.Log.ILogger<T>** for logging
- **IMetrics** for metrics (no MonitorWrapper in Trading NuGets)
- **FluentValidation** for request validation
- **AutoMapper** for DTO mapping

---

## Open Items (None)

All NEEDS CLARIFICATION items have been resolved. No open items remain.
