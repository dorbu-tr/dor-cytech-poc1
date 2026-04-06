# Data Model: Trading Positions API

**Branch**: `001-trading-positions-api` | **Date**: 2026-03-31

## Entity Overview

This service is an **aggregator** — it does not persist data. All entities below represent in-memory DTOs that map between the upstream API responses and our service's API contract.

---

## Domain Enumerations

### PositionStatus
Business concept representing the state of a trading position.

| Value | Description |
|-------|-------------|
| Open | Position is currently active |
| Closed | Position has been closed |

**Location**: `Domain/Enumerations/PositionStatus.cs`

### CloseReason
Business concept representing why a position was closed.

| Value | Description |
|-------|-------------|
| UserRequested | User manually closed the position |
| StopLoss | Automatic close triggered by stop-loss |
| TakeProfit | Automatic close triggered by take-profit |
| MarginCall | Closed due to insufficient margin |
| Other | Other/unspecified reason |

**Location**: `Domain/Enumerations/CloseReason.cs`

---

## Application Layer DTOs

### Parameters (Input to Service)

#### GetPositionsParameters
| Field | Type | Source | Description |
|-------|------|--------|-------------|
| Cursor | string? | Request query | Base64-encoded cursor for pagination |
| PageSize | int | Request query (defaulted from config) | Number of items per page |
| InstrumentId | int? | Request query | Optional filter by instrument |
| StsToken | string | Request header (STS) | User's STS token for upstream auth |
| ApplicationIdentifier | string | Config | App identifier for upstream auth |
| ApplicationVersion | string | Config | App version for upstream auth |
| AccountType | string | Request header | Real or Demo |

#### GetPositionByIdParameters
| Field | Type | Source | Description |
|-------|------|--------|-------------|
| PositionId | long | Request route | The position ID to retrieve |
| StsToken | string | Request header (STS) | User's STS token |
| ApplicationIdentifier | string | Config | App identifier |
| ApplicationVersion | string | Config | App version |
| AccountType | string | Request header | Real or Demo |

#### ClosePositionParameters
| Field | Type | Source | Description |
|-------|------|--------|-------------|
| PositionId | long | Request route | The position ID to close |
| CloseReason | CloseReason? | Request body | Optional close reason enum |
| StsToken | string | Request header (STS) | User's STS token |
| ApplicationIdentifier | string | Config | App identifier |
| ApplicationVersion | string | Config | App version |
| AccountType | string | Request header | Real or Demo |

### Results (Output from Service)

#### GetPositionsResult
| Field | Type | Description |
|-------|------|-------------|
| Items | List\<PositionData\> | Page of position items |
| NextCursor | string? | Cursor for next page (null if last page) |
| HasNext | bool | Whether more pages exist |

#### GetPositionDetailResult
| Field | Type | Description |
|-------|------|-------------|
| Position | PositionData | Full position detail with instrument enrichment |

#### ClosePositionResult
| Field | Type | Description |
|-------|------|-------------|
| PositionId | long | The closed position ID |
| TrackingToken | string | Upstream async tracking token |

### Data Objects (Shared)

#### PositionData
| Field | Type | Description |
|-------|------|-------------|
| PositionId | long | Unique position identifier |
| InstrumentId | int | Instrument being traded |
| OpenRate | decimal | Entry price |
| OpenDateTime | DateTime | When the position was opened |
| IsBuy | bool | Long (true) or short (false) |
| Leverage | int | Leverage multiplier |
| Amount | decimal | USD amount allocated |
| Units | decimal | Units in position |
| TotalFees | decimal | Accumulated fees |
| TakeProfitRate | decimal? | Take-profit trigger price |
| StopLossRate | decimal? | Stop-loss trigger price |
| Instrument | InstrumentData? | Enriched instrument info (null if Instruments API unavailable) |

#### InstrumentData
| Field | Type | Description |
|-------|------|-------------|
| InstrumentId | int | Instrument identifier |
| TypeId | int | Instrument type (stock, crypto, etc.) |
| IsActive | bool | Derived from IsVisible && !IsDelisted |
| AllowClosePosition | bool | Whether closing is allowed for this instrument |

---

## Infrastructure Layer DTOs

### Provider DTOs — Positions API

#### GetPositionsResponse (Provider)
| Field | Type | Maps From | Description |
|-------|------|-----------|-------------|
| Positions | List\<PositionItem\> | `Positions[]` | Array of position objects |

#### PositionItem (Provider)
| Field | Type | Maps From | Description |
|-------|------|-----------|-------------|
| PositionID | long | `PositionID` | Position identifier |
| CID | int | `CID` | Customer identifier |
| OpenDateTime | DateTime | `OpenDateTime` | Open timestamp |
| OpenRate | decimal | `OpenRate` | Entry price |
| InstrumentID | int | `InstrumentID` | Instrument ID |
| IsBuy | bool | `IsBuy` | Direction |
| TakeProfitRate | decimal | `TakeProfitRate` | TP price |
| StopLossRate | decimal | `StopLossRate` | SL price |
| Amount | decimal | `Amount` | USD amount |
| Leverage | int | `Leverage` | Leverage |
| Units | decimal | `Units` | Units count |
| TotalFees | decimal | `TotalFees` | Fees |

**Note**: Only fields our service actually accesses are included per constitution (no unused fields in provider DTOs).

#### ClosePositionResponse (Provider)
| Field | Type | Maps From | Description |
|-------|------|-----------|-------------|
| Token | string | `Token` | Async tracking token |

### Provider DTOs — Instruments API

#### GetInstrumentResponse (Provider)
| Field | Type | Maps From | Description |
|-------|------|-----------|-------------|
| Instrument | InstrumentDetail | `Instrument` | Instrument data object |

#### InstrumentDetail (Provider)
| Field | Type | Maps From | Description |
|-------|------|-----------|-------------|
| InstrumentID | int | `InstrumentID` | Instrument ID |
| TypeID | int | `TypeID` | Type identifier |
| IsVisible | bool | `IsVisible` | Visibility flag |
| IsDelisted | bool | `IsDelisted` | Delisted flag |
| AllowClosePosition | bool | `AllowClosePosition` | Close allowed |

---

## API Layer DTOs

### Request DTOs

#### GetPositionsRequest
| Property | Binding | Type | Validation |
|----------|---------|------|------------|
| Cursor | [FromQuery] | string? | Optional; if provided, must be valid Base64 |
| PageSize | [FromQuery] | int? | Optional; if provided, must be 1–100 |
| InstrumentId | [FromQuery] | int? | Optional; if provided, must be > 0 |

#### GetPositionByIdRequest
| Property | Binding | Type | Validation |
|----------|---------|------|------------|
| PositionId | [FromRoute] | long | Required; must be > 0 |

#### ClosePositionRequest
| Property | Binding | Type | Validation |
|----------|---------|------|------------|
| PositionId | [FromRoute] | long | Required; must be > 0 |
| Body | [FromBody] | ClosePositionBody? | Optional |

#### ClosePositionBody
| Property | Type | Validation |
|----------|------|------------|
| CloseReason | string? | Optional; if provided, must be valid CloseReason enum value |

### Response DTOs

#### GetPositionsResponse (API)
| Property | Type | Description |
|----------|------|-------------|
| Items | List\<PositionItem\> | Position summaries |
| NextCursor | string? | Cursor for next page |
| HasNext | bool | More pages available |

#### GetPositionDetailResponse
| Property | Type | Description |
|----------|------|-------------|
| PositionId | long | Position identifier |
| InstrumentId | int | Instrument ID |
| OpenRate | decimal | Entry price |
| OpenDateTime | DateTime | Open timestamp |
| IsBuy | bool | Direction |
| Leverage | int | Leverage |
| Amount | decimal | USD amount |
| Units | decimal | Units |
| TotalFees | decimal | Fees |
| TakeProfitRate | decimal? | TP price |
| StopLossRate | decimal? | SL price |
| Instrument | InstrumentInfo? | Enriched instrument (nullable) |

#### ClosePositionResponse (API)
| Property | Type | Description |
|----------|------|-------------|
| PositionId | long | Closed position ID |
| TrackingToken | string | Async tracking token |

### Data Objects (API Nested)

#### PositionItem (API)
| Property | Type | Description |
|----------|------|-------------|
| PositionId | long | Position identifier |
| InstrumentId | int | Instrument ID |
| OpenRate | decimal | Entry price |
| OpenDateTime | DateTime | Open timestamp |
| IsBuy | bool | Direction |
| Leverage | int | Leverage |
| Amount | decimal | USD amount |
| Instrument | InstrumentInfo? | Enriched instrument (nullable) |

#### InstrumentInfo (API)
| Property | Type | Description |
|----------|------|-------------|
| InstrumentId | int | Instrument ID |
| TypeId | int | Type identifier |
| IsActive | bool | Active status |

#### PaginationCursor (API)
| Property | Type | Description |
|----------|------|-------------|
| NextCursor | string? | Opaque cursor token |
| HasNext | bool | Whether more results exist |

---

## Entity Relationships

```
GetPositionsResponse (API)
├── Items: List<PositionItem>
│   └── Instrument: InstrumentInfo? (enriched from Instruments API)
├── NextCursor: string?
└── HasNext: bool

GetPositionDetailResponse (API)
├── [position fields]
└── Instrument: InstrumentInfo? (enriched from Instruments API)

ClosePositionResponse (API)
├── PositionId
└── TrackingToken
```

---

## Validation Rules

| Field | Rule | Error Code |
|-------|------|------------|
| PositionId | Must be > 0 | InvalidPositionId |
| PageSize | Must be 1–100 (if provided) | InvalidPageSize |
| InstrumentId | Must be > 0 (if provided) | InvalidInstrumentId |
| Cursor | Must be valid Base64 (if provided) | InvalidCursor |
| CloseReason | Must be valid enum value (if provided) | InvalidCloseReason |

---

## State Transitions

```
Position lifecycle (upstream-managed):
  Open ──[close request]──> Closing ──[upstream processes]──> Closed
                                │
                                └── Our service returns TrackingToken
                                    for async status tracking
```

Our service does not manage state transitions — the upstream Positions API handles the full lifecycle. We only initiate the close action and return the tracking token.
