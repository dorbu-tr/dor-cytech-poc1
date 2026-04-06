# Feature Specification: Trading Positions API

**Feature Branch**: `001-trading-positions-api`
**Created**: 2026-03-31
**Status**: Draft
**Input**: User description: "Build a Trading Positions API service that allows users to manage their trading positions with GET list, GET detail, and POST close endpoints"

**Constitution Reference**: `.specify/memory/constitution.md` + `.specify/memory/constitution-team.md`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - List Open Positions (Priority: P1)

As an authenticated user, I want to retrieve a list of my open trading positions so I can see an overview of my current portfolio. I can page through large result sets using cursor-based pagination and optionally filter by a specific instrument to focus on positions for a particular asset.

**Why this priority**: This is the most fundamental read operation — users need to see what they own before taking any other action. It is the entry point for all position management workflows.

**Independent Test**: Can be fully tested by authenticating a user, calling GET /api/v1/positions, and verifying the paginated response contains the user's open positions. Delivers immediate value as a standalone portfolio view.

**Acceptance Scenarios**:

1. **Given** an authenticated user with 5 open positions, **When** they request GET /api/v1/positions, **Then** the response contains up to the default page size of positions with cursor metadata for the next page.
2. **Given** an authenticated user with positions across multiple instruments, **When** they request GET /api/v1/positions?instrumentId=1234, **Then** only positions for instrument 1234 are returned.
3. **Given** an authenticated user with more positions than one page, **When** they request GET /api/v1/positions?cursor={nextCursor}, **Then** the next page of results is returned with updated cursor metadata.
4. **Given** an authenticated user with no open positions, **When** they request GET /api/v1/positions, **Then** an empty collection is returned with no next cursor.
5. **Given** an unauthenticated request, **When** GET /api/v1/positions is called, **Then** a 401 Unauthorized response is returned.

**Component Test Scenarios**:
- Test case: Authenticated user with positions → Expected: 200 OK, response contains position items array and pagination cursor
- Test case: Authenticated user with no positions → Expected: 200 OK, empty items array, null next cursor
- Test case: Filter by valid instrumentId → Expected: 200 OK, only matching positions returned
- Test case: Filter by instrumentId with no matches → Expected: 200 OK, empty items array
- Test case: Invalid cursor value → Expected: 400 Bad Request with validation error
- Test case: Missing/invalid auth token → Expected: 401 Unauthorized
- Test case: Upstream Positions API unavailable → Expected: 502 Bad Gateway or graceful degradation

**System Test Scenarios**:
- Test case: Authenticated user lists positions → Expected: 200 OK with valid position data from real Positions API
- Test case: Pagination cursor navigates through full result set → Expected: All positions returned across pages with no duplicates

---

### User Story 2 - View Position Details (Priority: P1)

As an authenticated user, I want to view the full details of a specific trading position so I can see its instrument, open rate, current profit/loss, leverage, and open date to make informed trading decisions.

**Why this priority**: Equally critical as listing — users need detailed position information to evaluate their trades. This is a core read operation paired with the list endpoint.

**Independent Test**: Can be fully tested by authenticating a user, calling GET /api/v1/positions/{positionId} with a known position ID, and verifying the response contains complete position metadata. Delivers standalone value as a position detail view.

**Acceptance Scenarios**:

1. **Given** an authenticated user who owns position 999, **When** they request GET /api/v1/positions/999, **Then** the response contains position details including instrument info, open rate, current P&L, leverage, and open date.
2. **Given** an authenticated user, **When** they request a position ID they do not own, **Then** a 404 Not Found response is returned (position is not visible to this user).
3. **Given** an authenticated user, **When** they request a position ID that does not exist, **Then** a 404 Not Found response is returned.
4. **Given** an unauthenticated request, **When** GET /api/v1/positions/{positionId} is called, **Then** a 401 Unauthorized response is returned.

**Component Test Scenarios**:
- Test case: Authenticated user requests own position → Expected: 200 OK with full position detail (instrument, openRate, currentPnL, leverage, openDate)
- Test case: Authenticated user requests position they don't own → Expected: 404 Not Found
- Test case: Authenticated user requests non-existent position → Expected: 404 Not Found
- Test case: Invalid positionId format (non-numeric) → Expected: 400 Bad Request with validation error
- Test case: Missing/invalid auth token → Expected: 401 Unauthorized
- Test case: Upstream Positions API unavailable → Expected: 502 Bad Gateway or graceful degradation

**System Test Scenarios**:
- Test case: Authenticated user retrieves a known position → Expected: 200 OK with position metadata matching expected values

---

### User Story 3 - Close a Position (Priority: P2)

As an authenticated user, I want to close one of my open trading positions so I can realize my profit or cut my losses. I can optionally provide a reason for closing the position.

**Why this priority**: This is the primary write/action operation. While essential to the service, it depends on users first being able to list and view their positions (P1 stories). Closing is a destructive action with financial implications, so it is sequenced after the read operations.

**Independent Test**: Can be fully tested by authenticating a user, calling POST /api/v1/positions/{positionId}/close on a known open position, and verifying the position is closed. Delivers the ability to exit a trade.

**Acceptance Scenarios**:

1. **Given** an authenticated user who owns open position 999, **When** they request POST /api/v1/positions/999/close, **Then** the position is closed and a success response is returned.
2. **Given** an authenticated user who owns open position 999, **When** they request POST /api/v1/positions/999/close with closeReason "UserRequested", **Then** the position is closed with that reason recorded and a success response is returned.
3. **Given** an authenticated user, **When** they attempt to close a position they do not own, **Then** a 404 Not Found response is returned and no position is closed.
4. **Given** an authenticated user, **When** they attempt to close a position that is already closed, **Then** a 409 Conflict response is returned indicating the position is not open.
5. **Given** an authenticated user, **When** they provide an invalid closeReason value, **Then** a 400 Bad Request response is returned with a validation error.
6. **Given** an unauthenticated request, **When** POST /api/v1/positions/{positionId}/close is called, **Then** a 401 Unauthorized response is returned.

**Component Test Scenarios**:
- Test case: Authenticated user closes own open position without reason → Expected: 200 OK, position closed
- Test case: Authenticated user closes own open position with valid closeReason → Expected: 200 OK, position closed with reason
- Test case: Authenticated user attempts to close position they don't own → Expected: 404 Not Found
- Test case: Authenticated user attempts to close already-closed position → Expected: 409 Conflict
- Test case: Invalid closeReason enum value → Expected: 400 Bad Request with validation error
- Test case: Invalid positionId format → Expected: 400 Bad Request with validation error
- Test case: Missing/invalid auth token → Expected: 401 Unauthorized
- Test case: Upstream Positions API unavailable → Expected: 502 Bad Gateway or graceful degradation

**System Test Scenarios**:
- Test case: Authenticated user closes an open position → Expected: 200 OK, subsequent GET for that position reflects closed status

---

### Edge Cases

- What happens when the Positions API returns a timeout? The service should return a 504 Gateway Timeout with appropriate retry headers.
- What happens when the Instruments API is down but Positions API is healthy? The service should degrade gracefully — return position data with instrument information omitted or marked as unavailable, rather than failing the entire request.
- What happens when a user sends a close request for a position that is being closed concurrently? The service should handle idempotency — if the position is already in a "closing" state, return 409 Conflict.
- What happens when cursor-based pagination parameters reference an expired or invalid cursor? Return 400 Bad Request with a clear error message.
- What happens when the instrumentId filter value is not a valid instrument? Return an empty result set (200 OK with no items), not an error.
- What are the timeout/retry behaviors for external calls? Positions API: 2000ms timeout, 2 retries with exponential backoff. Instruments API: 1000ms timeout, 2 retries with exponential backoff.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST authenticate all requests using STS tokens and extract the user's internal ID from the token claims.
- **FR-002**: System MUST expose GET /api/v1/positions to return all open positions for the authenticated user.
- **FR-003**: System MUST support cursor-based pagination on the list positions endpoint with a configurable default page size.
- **FR-004**: System MUST support optional filtering by instrumentId query parameter on the list positions endpoint.
- **FR-005**: System MUST expose GET /api/v1/positions/{positionId} to return full details of a single position owned by the authenticated user.
- **FR-006**: System MUST return position details including: instrument information, open rate, current profit/loss, leverage, and open date.
- **FR-007**: System MUST expose POST /api/v1/positions/{positionId}/close to close an open position owned by the authenticated user.
- **FR-008**: The close endpoint MUST accept an optional closeReason enum in the request body (valid values: UserRequested, StopLoss, TakeProfit, MarginCall, Other).
- **FR-009**: System MUST return 404 Not Found when a user requests or acts on a position they do not own or that does not exist.
- **FR-010**: System MUST return 409 Conflict when a user attempts to close a position that is not in an open state.
- **FR-011**: System MUST validate all request inputs and return 400 Bad Request with structured error responses for invalid data.
- **FR-012**: System MUST enrich position data by combining responses from the internal Positions API and Instruments API.

### Non-Functional Requirements

- **NFR-001**: Performance: GET endpoints must respond within 150ms at the 95th percentile under normal load.
- **NFR-002**: Performance: The close position endpoint must respond within 300ms at the 95th percentile under normal load.
- **NFR-003**: Reliability: The service must implement circuit breaker patterns for both upstream API dependencies (Positions API and Instruments API).
- **NFR-004**: Reliability: If the Instruments API is unavailable, the service should degrade gracefully and still return position data without enriched instrument details.
- **NFR-005**: Security: All endpoints require STS token authentication; no PII is stored or logged. Only internal user IDs are used.
- **NFR-006**: Security: Communication with upstream services (Positions API, Instruments API) uses API key authentication.
- **NFR-007**: Observability: All service methods must be wrapped with monitoring (MonitorWrapper). Structured logging with correlation IDs must be present on all requests.
- **NFR-008**: Observability: Health endpoints must check connectivity to both upstream dependencies.
- **NFR-009**: Maintainability: Class sizes must remain under 200 lines. Code must follow Clean Architecture layering.
- **NFR-010**: Deployment: Service deploys to Front cluster (31). No PCI scope applies.
- **NFR-011**: Data classification: Internal. No PII is stored — users are referenced solely by internal ID extracted from the STS token.

### Key Entities

- **Position**: Represents a user's trading position. Key attributes: positionId, userId (internal), instrumentId, openRate, currentPnL, leverage, openDate, status (Open/Closed), closeReason (optional).
- **Instrument**: Reference data about a tradable asset. Key attributes: instrumentId, name, symbol, type. Sourced from the Instruments API for enrichment purposes.
- **CloseReason**: An enumeration of reasons a position may be closed: UserRequested, StopLoss, TakeProfit, MarginCall, Other.

## External Dependencies

### Internal eToro Services (Use API Discovery MCP)

| Service         | API Discovery Status | Contract Defined | Auth Method | Timeout | Retry Policy                        |
| --------------- | -------------------- | ---------------- | ----------- | ------- | ----------------------------------- |
| Positions API   | [ ] Discovered       | [ ]              | API Key     | 2000ms  | 2 retries, exponential backoff      |
| Instruments API | [ ] Discovered       | [ ]              | API Key     | 1000ms  | 2 retries, exponential backoff      |

## Infrastructure NuGets Required

| NuGet Package                                        | Required | MCP Documentation Reviewed |
| ---------------------------------------------------- | -------- | -------------------------- |
| `eToro.Infrastructure.CentralConfigurationManager`   | ✅        | [ ]                        |
| `eToro.Infrastructure.Monitoring.Mvc`                | ✅        | [ ]                        |
| `eToro.Infrastructure.Logging`                       | ✅        | [ ]                        |
| `eToro.Infrastructure.Metrics`                       | ✅        | [ ]                        |
| `eToro.Infrastructure.Tests.Component`               | ✅        | [ ]                        |
| `eToro.Infrastructure.Tests.System`                  | ✅        | [ ]                        |
| `eToro.Infrastructure.Resilience` (circuit breaker)  | [ ]      | [ ]                        |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All component tests pass for list, detail, and close endpoints including error scenarios.
- **SC-002**: Health endpoints return healthy status when both upstream dependencies are reachable.
- **SC-003**: Users can list their open positions with pagination and filter by instrument.
- **SC-004**: Users can view complete details of any position they own.
- **SC-005**: Users can close an open position, optionally providing a reason.
- **SC-006**: GET endpoints respond within 150ms at the 95th percentile under normal load.
- **SC-007**: Close endpoint responds within 300ms at the 95th percentile under normal load.
- **SC-008**: Service gracefully degrades when the Instruments API is unavailable, still returning position data.
- **SC-009**: System tests are written and ready for CI/CD execution against integration environment.

### Constitution Compliance Checklist

- [ ] All phases completed in order (Interfaces → Domain → Infrastructure → Application → Api)
- [ ] Monitoring wrapper on all public async service methods
- [ ] Class sizes < 200 lines
- [ ] **Controller Method Pattern (Section XI)**: Single request object per method, NO `[FromQuery]`/`[FromRoute]`/`[FromBody]` on method params
- [ ] **Authentication**: Auth attribute on client-facing endpoints, backend auth filter on API key endpoints
- [ ] Request DTOs have `Validate()` method, binding attributes on **properties**
- [ ] **Request Validation Error Pattern**: ErrorCode enum + ErrorMessageConsts + RequestValidationException
- [ ] Validation uses `string.Format(ErrorMessageConsts.X, nameof(Property))` - NO hard-coded messages
- [ ] **Request Default Values Pattern**: NO hardcoded defaults in DTOs - defaults MUST come from ConfigurationProvider
- [ ] Application services use `Normalize*()` methods to apply defaults from configuration
- [ ] `Internalize()`/`Externalize()` extension methods for request/response conversion
- [ ] Component tests implemented and passing
- [ ] System tests implemented (written only - DO NOT run locally, CI/CD handles execution)
- [ ] External dependencies have contracts + mocks + health checks
- [ ] Logging cleaned for production

## Assumptions

- The default page size for cursor-based pagination is configurable via CCM/configuration, not hardcoded. A reasonable default is 20 items per page.
- The closeReason field in the close request body is optional; if omitted, the system passes null/none to the upstream Positions API.
- The "current P&L" value is computed by the upstream Positions API — this service does not perform P&L calculations.
- Position ownership is determined by matching the user's internal ID (from the STS token) against the userId on the position record returned by the upstream Positions API.
- The close operation is synchronous from the client's perspective — the upstream Positions API handles the close and returns a result within the timeout window.
- Instrument enrichment is a "best effort" enhancement: if the Instruments API is unavailable, positions are still returned without instrument details (name, symbol, type) rather than failing the request entirely.
