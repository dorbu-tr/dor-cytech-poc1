# Security Review: Trading Positions API

**Date**: 2026-03-31
**Plan**: [plan.md](plan.md)
**Mode**: Shadow

## Cluster Determination

| Question | Answer | Impact |
|----------|--------|--------|
| Q1: Service domain? | **Trading** | → Trading cluster (skips Q2–Q4 for cluster decision) |
| Q2: Frontend-facing? | **Yes** (STS client-facing endpoints) | Noted for service classification |
| Q3: eToro DB access? | **No** | Consistent with plan (aggregator, no database) |
| Q4: Other DB access? | **No** | Consistent with plan (no database) |

**Recommended cluster**: Trading cluster (Q1=Trading)
**Plan declared cluster**: Trading (updated)
**Confirmed cluster**: Trading cluster — **MATCH**

## Service Security Profile

| Attribute | Declared Value | Assessment |
|-----------|---------------|------------|
| Data Classification | Internal | PASS |
| Service Type | Wrapper-proxy | PASS — aggregator of two internal APIs, no DB |
| Target Cluster | Trading | PASS — matches Q1=Trading recommendation |
| eToroDB Access | No | PASS |
| PII Handling | None | PASS |
| Sensitive Dependencies | None | PASS |
| Authentication | STS client-facing | PASS |
| External-Facing | Yes — 3 endpoints (Internal data) | PASS — all endpoints STS-authenticated |
| PCI Scope | No | PASS |

## Criteria Evaluation

### Auto-Approve Criteria

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| A1 | Data classification = Public or Internal | PASS | Declared as Internal; no PII stored, only internal user IDs from STS tokens |
| A2 | No direct eToroDB access | PASS | eToroDB Access = No; all DB NuGets excluded from checklist; aggregator pattern with no database |
| A3 | No PII storage/processing | PASS | PII Handling = None; users referenced by internal ID only |
| A4 | No sensitive dependencies | PASS | Both upstream APIs (Positions, Instruments) are internal services; no PCI/financial secrets |
| A5 | Auth present on private endpoints | PASS | STS token authentication on all 3 endpoints |
| A6 | No PII/secrets in logs | PASS | Plan confirms structured logging with Framework.Log, no PII logging, `[SensitiveData]` discipline |
| A7 | Cluster placement matches service type | PASS | Trading domain → Trading cluster; plan updated to Trading |
| A8 | Service matches qualifying type | PASS | Wrapper-proxy: thin aggregation layer over two internal APIs, no data processing or DB |

### Auto-Reject Criteria (Plan-Stage)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| R1 | PII in logs without masking | PASS | Plan confirms: "No PII stored, logged, or processed"; logging discipline planned |
| R4 | Sensitive endpoint without auth | PASS | All 3 endpoints require STS token authentication |
| R6 | Data classification mismatch | PASS | Internal classification consistent with service behavior: aggregates Internal trading data from upstream APIs, no DB, no PII |
| R11 | Missing input validation | PASS | FluentValidation declared for all 3 request DTOs with specific field-level rules |
| R12 | Cluster placement mismatch | PASS | Trading cluster matches Q1=Trading recommendation |
| **DYN-R8** | **Hardcoded internal IP in plan** | **FAIL** | **Phase 3 declares connectivity verification using hardcoded IP: `http://10.0.5.120:8080/healthcheck`. R8 prohibits hardcoded internal IPs, hostnames, or connection strings — these expose infrastructure topology and MUST be in CCM/KeyVault. While R8 is normally a post-commit check, the plan explicitly declares intent to hardcode an internal IP address.** |

### Manual Review Triggers

| # | Trigger | Detected | Evidence |
|---|---------|----------|----------|
| M1 | PCI scope | NO | PCI Scope = No |
| M2 | Auth/authz module changes | NO | Uses existing STS auth; no new auth module |
| M3 | Unclear or mixed data classification | NO | Internal classification consistent: no DB, no PII, aggregator pattern |
| M4 | Trading or Money cluster | **YES** | Q1=Trading; Trading cluster confirmed. Trading domain services require elevated review. |
| M5 | Ambiguous external-facing endpoints | NO | 3 endpoints clearly defined with data sensitivity and authentication |
| M6 | Confidential data classification | NO | Declared as Internal |
| M7 | Restricted data with authenticated access | NO | No Restricted data |
| M8 | Cluster-deployment skill conflict | NO | No conflict — Trading cluster matches recommendation |

## Verdict: Auto-reject

**[SHADOW MODE]** This verdict is advisory only. Human validation is required.

### Rejection Reasons

1. **DYN-R8 — Hardcoded internal IP address in plan**: Phase 3 (Infrastructure Layer) declares a connectivity verification step using a hardcoded internal IP: `http://10.0.5.120:8080/healthcheck`. Per R8, hardcoded internal IPs, hostnames, and connection strings expose infrastructure topology and are prohibited — all service URLs MUST be sourced from CCM (etcd) or KeyVault configuration.

   **Remediation**:
   - Remove the hardcoded IP `http://10.0.5.120:8080/healthcheck` from the plan
   - Replace with a configuration-driven reference: "Positions API base URL and health check URL sourced from `PositionsApiConfiguration` (CCM)"
   - The `PositionsApiConfiguration.cs` already exists in the plan's project structure for this purpose
   - Re-run `/speckit.cytech-plan` after the fix

### Additional Notes

- All 8 auto-approve criteria (A1–A8) **PASS** — the service would qualify for auto-approve if not for the hardcoded IP and the Trading cluster trigger
- **M4 is triggered** (Trading cluster) — even after fixing DYN-R8, the service will receive a **Manual review** verdict (Trading domain requires elevated security review)
- The underlying service architecture is sound: aggregator pattern, no DB, no PII, STS auth, proper validation
