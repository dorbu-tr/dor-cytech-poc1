# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`
**Created**: [DATE]
**Status**: Draft
**Input**: User description: "$ARGUMENTS"

**Constitution Reference**: `.specify/memory/constitution.md` + `.specify/memory/constitution-team.md`

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  
  Per Constitution: Testing is MANDATORY. Each story must have:
  - Component tests (mocked external dependencies)
  - System tests (real API calls against integration environment)
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

**Component Test Scenarios**:
- Test case: [Description] → Expected: [HTTP status, response shape]
- Test case: [Description] → Expected: [HTTP status, error response]

**System Test Scenarios**:
- Test case: [Description] → Expected: [Real API response validation]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

**Component Test Scenarios**:
- Test case: [Description] → Expected: [HTTP status, response shape]

**System Test Scenarios**:
- Test case: [Description] → Expected: [Real API response validation]

---

### Edge Cases

- What happens when [boundary condition]?
- How does system handle [error scenario]?
- What are the timeout/retry behaviors for external calls?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST [specific capability]
- **FR-002**: System MUST [specific capability]
- **FR-003**: Users MUST be able to [key interaction]
- **FR-004**: System MUST [data requirement]
- **FR-005**: System MUST [behavior]

*Mark unclear requirements with NEEDS CLARIFICATION:*
- **FR-006**: System MUST [NEEDS CLARIFICATION: detail not specified]

### Non-Functional Requirements

- **NFR-001**: Performance: [e.g., <100ms p95 response time]
- **NFR-002**: Reliability: [e.g., 99.9% uptime, graceful degradation]
- **NFR-003**: Security: [e.g., STS token validation for client endpoints, API key validation for backend-to-backend endpoints, no PII in logs]
- **NFR-004**: Observability: [e.g., structured logging, metrics, health endpoints]
- **NFR-005**: Maintainability: [e.g., class size <200 lines, MonitorWrapper on all async methods]

### Key Entities *(include if feature involves data)*

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## External Dependencies

<!--
  Per Constitution: For EVERY external call, define:
  - Contract: request/response schema + error schema
  - Auth: token acquisition/refresh rules
  - Timeout/Retry/Backoff: explicit values
  - Mock: local stub/mocking strategy
  - Health check: dependency health verification
-->

### Internal eToro Services (Use API Discovery MCP)

| Service | API Discovery Status | Contract Defined | Auth Method | Timeout | Retry Policy |
|---------|---------------------|------------------|-------------|---------|--------------|
| [Service 1] | [ ] Discovered | [ ] | STS / API Key / None | [ms] | [Polly policy] |
| [Service 2] | [ ] Discovered | [ ] | STS / API Key / None | [ms] | [Polly policy] |

### External Services

| Service | Contract Defined | Auth Method | Timeout | Retry Policy | Health Check |
|---------|------------------|-------------|---------|--------------|--------------|
| [Service 1] | [ ] | [API Key / OAuth] | [ms] | [Polly policy] | [ ] |

<!-- TEAM-SPECIFIC: START - Replace this section with your team's required library packages -->
## Infrastructure NuGets Required

<!--
  Per Constitution: Check each NuGet via infra MCP before implementation
-->

| NuGet Package | Required | MCP Documentation Reviewed |
|--------------|----------|---------------------------|
| `eToro.Infrastructure.CentralConfigurationManager` | ✅ | [ ] |
| `eToro.Infrastructure.Monitoring.Mvc` | ✅ | [ ] |
| `eToro.Infrastructure.Logging` | ✅ | [ ] |
| `eToro.Infrastructure.Metrics` | ✅ | [ ] |
| `eToro.Infrastructure.Tests.Component` | ✅ | [ ] |
| `eToro.Infrastructure.Tests.System` | ✅ | [ ] |
| [Add based on requirements] | [ ] | [ ] |
<!-- TEAM-SPECIFIC: END -->

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "All component tests pass"]
- **SC-002**: [Measurable metric, e.g., "Health endpoints return healthy status"]

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
