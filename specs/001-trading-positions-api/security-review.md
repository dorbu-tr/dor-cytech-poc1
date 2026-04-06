# Security Review: Trading Positions API

**Date**: 2026-04-06
**Plan**: [plan.md](plan.md)
**Mode**: Shadow

> **[SHADOW MODE]** This verdict is advisory only. Human validation is required.

## Cluster Determination

| Input Signal | Value | Source |
|-------------|-------|--------|
| Domain | Trading | constitution-team.md (eToro Trading NuGets team) |
| eToroDB Access | No | Service Security Profile |
| Authentication Model | STS client-facing | Service Security Profile |
| Service Type | Wrapper-proxy | Service Security Profile |

**Decision path**: Q1 = Trading → Trading cluster (first-match rule, skip Q2–Q4).

**Derived recommendation**: Trading cluster
**Declared in plan.md**: Trading cluster
**Comparison**: MATCH — PASS

## Service Security Profile

| Attribute | Declared Value | Assessment |
|-----------|---------------|------------|
| Data Classification | Internal | PASS — no PII, no credentials, only internal trading IDs and rates |
| Service Type | Wrapper-proxy | PASS — aggregates two internal APIs, no business logic persistence |
| Target Cluster | Trading | PASS — matches cluster-deployment recommendation for Trading domain |
| eToroDB Access | No | PASS — aggregator with no database access |
| PII Handling | None | PASS — users referenced by internal ID from STS token only |
| Sensitive Dependencies | None | PASS — Positions API and Instruments API are internal non-sensitive services |
| Authentication | STS client-facing | PASS — all three endpoints require STS token authentication |
| External-Facing | Yes — 3 endpoints (GET list, GET detail, POST close) | PASS — all authenticated, Internal data only |
| PCI Scope | No | PASS |

## Criteria Evaluation

### Auto-Approve Criteria (A1–A8)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| A1 | Data classification = Public or Internal | PASS | Declared as Internal; service handles trading position IDs, rates, and instrument metadata — no PII, no credentials |
| A2 | No direct eToroDB access | PASS | Declared eToroDB Access = No; no SQL packages in NuGets checklist; aggregator pattern |
| A3 | No PII storage/processing | PASS | PII Handling = None; users referenced solely by internal ID from STS token |
| A4 | No sensitive dependencies | PASS | Both upstream APIs (Positions API, Instruments API) are internal services handling trading data, not PCI/financial secrets |
| A5 | Auth present on private endpoints | PASS | STS client-facing authentication on all three endpoints; OpenAPI spec declares `stsAuth` security scheme globally |
| A6 | No PII/secrets in logs | PASS | Plan establishes logging discipline with Framework.Log, confirms "no PII stored, logged, or processed" |
| A7 | Cluster placement matches service type | PASS | Trading domain → Trading cluster; plan declares Trading; matches cluster-deployment recommendation |
| A8 | Service matches qualifying type | PASS | Wrapper-proxy (aggregator of two internal APIs) is a qualifying type |

### Auto-Reject Criteria (R1–R12)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| R1 | PII in logs without masking | PASS | Plan declares "no PII stored, logged, or processed"; logging discipline with Framework.Log established |
| R2 | Hardcoded secrets/credentials | PASS | No API keys, passwords, tokens, or connection strings found in plan text; API keys referenced as being in KeyVault |
| R3 | Secrets embedded in plan text | PASS | No active secrets found in plan text |
| R4 | Sensitive endpoint without auth | PASS | All three endpoints declare STS authentication; OpenAPI spec enforces `stsAuth` globally |
| R5 | Plan/spec internal contradictions | **FAIL** | **Spec NFR-010 declares "Service deploys to Front cluster (31)"** but plan declares "Target Cluster: Trading". The plan's cluster is CORRECT per cluster-deployment rules (Trading domain → Trading cluster) and is MORE restrictive than the spec's declaration. The spec contains an error that must be corrected. |
| R6 | Data classification mismatch | PASS | Internal classification is appropriate — service accesses trading position data (IDs, rates, amounts) and instrument metadata, all Internal-level |
| R7 | Known vulnerable dependencies | PASS | No dependencies with known critical/high CVEs declared; uses standard eToro Trading NuGets and mainstream packages (Polly, FluentValidation, AutoMapper) |
| R8 | Hardcoded IPs/hostnames/connection strings | **FAIL** | **Plan Phase 3 contains hardcoded IP**: "call Positions API health endpoint at `http://10.0.5.120:8080/healthcheck`". Per policy, all URLs/hostnames must be in CCM or KeyVault, not hardcoded in plan text. |
| R9 | Overly permissive IAM/RBAC | PASS | No wildcard permissions or overly permissive roles declared |
| R10 | Sensitive data in error responses | PASS | Uses template-provided ExceptionHandlingMiddleware with `application/problem+json`; no indication of stack traces or PII in error responses |
| R11 | Missing input validation | PASS | FluentValidation declared for all three request types; ClosePositionBody has enum validation for closeReason; validation checklist confirms all inputs validated |
| R12 | Cluster placement mismatch | PASS | Derived recommendation (Trading) matches declared cluster (Trading) |

### Manual Review Triggers (M1–M8)

| # | Trigger | Detected | Evidence |
|---|---------|----------|----------|
| M1 | PCI scope | NO | PCI Scope = No |
| M2 | Auth/authz module changes | NO | Uses template-provided AppSecretAuthenticationMiddleware and STS `[Authentication]` attribute; no auth module being created or modified |
| M3 | Unclear or mixed data classification | NO | Data classification clearly declared as Internal with justification |
| M4 | Trading or Money cluster | **YES** | Target Cluster = Trading; Trading cluster services require elevated review |
| M5 | Ambiguous external-facing endpoints | NO | All three endpoints clearly documented with data sensitivity (Internal data) |
| M6 | Confidential data classification | NO | Data Classification = Internal, not Confidential |
| M7 | Restricted data with authenticated access | NO | No Restricted data involved |
| M8 | Cluster-deployment skill conflict | NO | No conflict; Trading domain → Trading cluster, plan declares Trading, derived recommendation matches |

### Additional Notes

| # | Finding | Severity | Details |
|---|---------|----------|---------|
| DYN-1 | Security Profile describes close endpoint `reason` field as "free-text string, up to 500 chars" | Info | The data model and OpenAPI spec define this as a `CloseReason` enum (not free-text). If it IS free-text, ensure proper sanitization before passing to upstream API. The plan declares FluentValidation for this field, so validation is present regardless. |

## Verdict: Auto-reject

> **[SHADOW MODE]** This verdict is advisory only and does NOT block progression. Human validation is required.

### Rejection Reasons

1. **R5 — Plan/spec internal contradictions (cluster)**: Spec NFR-010 declares "Service deploys to Front cluster (31)" while plan.md declares "Target Cluster: Trading". Although the plan's Trading cluster is the CORRECT and MORE RESTRICTIVE placement per cluster-deployment rules (Trading domain → Trading cluster), the documents contradict each other.

   **Remediation**: Update `spec.md` NFR-010 to read: "Deployment: Service deploys to Trading cluster. No PCI scope applies." Then re-run `/speckit.cytech-plan`.

2. **R8 — Hardcoded IP address in plan text**: Plan Phase 3 contains `http://10.0.5.120:8080/healthcheck` as a connectivity verification target. All hostnames, IPs, and URLs must be sourced from CCM or KeyVault configuration — never hardcoded.

   **Remediation**: Remove the hardcoded IP from plan.md Phase 3. Replace with a reference to the configuration key (e.g., "call Positions API health endpoint using the URL from `PositionsApiConfiguration.HealthCheckUrl`"). Then re-run `/speckit.cytech-plan`.

### Manual Review Note

Even after resolving the auto-reject items, this service would trigger **M4 (Trading cluster)**, requiring elevated review. In shadow mode this is advisory; in autonomous mode it would require security architect sign-off.
