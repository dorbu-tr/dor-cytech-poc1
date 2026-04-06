---
name: "core-cluster-deployment"
description: ">-"
metadata:
  short-description: ">-"
---

<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/skills/core/cluster-deployment/SKILL.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->
# Production Cluster Deployment Recommendation

## Overview

eToro production services are deployed to one of several AKS clusters based on
two decision axes: **domain ownership** (which team/domain the service belongs to)
and **technical requirements** (database access, service type).

This skill analyzes the current project and returns a cluster recommendation.

---

## Cluster Map

| Cluster | Subnet | Description |
|---------|--------|-------------|
| **Front** | 31 | Client-facing / frontend services. No direct DB access. |
| **BE** | 21 | Backend services without direct eToroDB access. |
| **BE with eToro DB** | 11 | Backend services with direct eToroDB access. |
| **Trading** | — | All Trading-domain services (provides FE + BE + eToro DR). |
| **Money** | — | All Money/Payments-domain services. Isolated cluster. |

### Networking

- **Ingress**: All external traffic enters through **Cloudflare**.
- **Intra-cluster** (service → resource): Managed identity / connection string per resource.
- **Cross-cluster** (service → service): Cluster Subnet → HA Proxy → target service (requires DNS entry).
- **PCI / WALLET**: Out of scope — requires manual security review.

---

## Decision Rules (ordered — first match wins)

```
1. Domain = Trading                → Trading cluster
2. Domain = Money                  → Money cluster
3. PCI / WALLET scope              → STOP — manual review required
4. Has eToroDB access              → Cluster 11 (BE with eToro DB)
5. Has massive business logic      → Cluster 21 (BE)
6. Backend service (no eToroDB)    → Cluster 21 (BE)
7. Frontend-only service           → Cluster 31 (Front)
```

### Massive Business Logic → Cluster 21 (BE)

Services that contain **significant business logic** (complex orchestration, multi-step
workflows, heavy data transformation, aggregation across multiple APIs, rule engines,
calculation services) belong in **Cluster 21 (BE)** even if they also serve client-facing
endpoints. The Front cluster (31) is reserved for thin pass-through / BFF services only.

**Indicators of massive business logic**:
- Application layer with many service classes containing complex orchestration
- Multiple REST provider dependencies (calling 3+ external APIs)
- Domain layer with business rules, validators, state machines
- Heavy data mapping / transformation between providers and responses
- Caching layers (Redis, InMemory) for computed/aggregated data
- Background jobs or scheduled tasks alongside API endpoints

---

## Analysis Steps

### Step 1 — Detect Domain / Team

Read `.specify/memory/constitution-team.md` and look at the first heading.

| Constitution header contains | Domain |
|------------------------------|--------|
| `Trading` | Trading |
| `Money` or `Payments` | Money |
| Anything else (Infrastructure, Onboarding, Operations…) | General — continue to Step 2 |

**Fallback signals** (if constitution-team.md is missing):
- `shared.props` at repo root with `TradingCoreBuildVersion` → Trading
- `.cursor/skills/team/` contains `trading-*` skill names → Trading
- NuGet packages prefixed with `eToro.Trading.*` → Trading

If the domain is **Trading** → recommend **Trading cluster** and skip to Step 4.
If the domain is **Money** → recommend **Money cluster** and skip to Step 4.

### Step 2 — Detect eToroDB Access

Scan all `.csproj` files under `src/` for database-related packages:

**Direct eToroDB indicators** (any ONE = has eToroDB access):
- `Microsoft.Data.SqlClient`
- `eToro.Trading.Sql.DbAccess`
- `eToro.Trading.Sql.Persistors`
- `eToro.Infrastructure.Providers.DocumentDb.Cosmos`
- `System.Data.SqlClient`

**Supporting evidence** (strengthen the signal):
- Repository classes in `Infrastructure/Repositories/Concrete/` (excluding `.reference/`)
- Connection string entries in `appsettings.json` (e.g., `"ConnectionStrings"`, `"SqlConnection"`)
- Stored procedure references (`EXEC`, `sp_`, `CREATE PROCEDURE`)
- Redis/Cosmos configuration in CCM config keys
- `eToro.Infrastructure.Caching.Redis` (Redis alone = caching, not eToroDB — only counts if paired with SQL)

If **any direct eToroDB indicator** is found → recommend **Cluster 11 (BE with eToro DB)** and skip to Step 3.

### Step 3 — Detect Service Type (Frontend vs Backend)

Scan controllers in `src/*/Controllers/` or `src/*/WebApi/Controllers/`:

| Signal | Means |
|--------|-------|
| `[Authentication]` attribute on actions | Client-facing (STS token from end users) |
| `[AdminActionFilter]` or `AppSecretAuthenticationMiddleware` | Backend-to-backend |
| `[AuthorizeLevel]` attribute | Backend (Trading ops-tool pattern) |
| Mix of `[Authentication]` + `[AdminActionFilter]` | Backend (serves both, but deployed as backend) |
| No controllers found (worker service only) | Backend |

**Decision**:
- If ALL controllers use only `[Authentication]` with NO backend auth and NO DB access → **Cluster 31 (Front)**
- Otherwise → **Cluster 21 (BE)**

### Step 3b — Resolve Conflicts (ASK THE USER)

If at any point during the analysis you encounter **conflicting signals** or are **not 100% confident** in the recommendation, you **MUST** stop and ask the user before returning a result.

**When to ask**:
- Mixed auth patterns that could point to either Front (31) or BE (21)
- The service has business logic but it's unclear whether it's "massive" or lightweight
- eToroDB indicators exist only in `.reference/` files (template examples, not real code)
- The domain is ambiguous (e.g., a service that spans Trading and another domain)
- The project is freshly scaffolded with no real implementation yet — ask the user about their planned requirements (eToroDB access, service type, business logic complexity)
- PCI/WALLET signals are weak (e.g., the word "payment" appears but it might not be PCI-scoped)

**How to ask**:
Present the conflicting evidence clearly and ask targeted questions:
```
I found conflicting signals for cluster placement:
- Signal A points to Cluster X because…
- Signal B points to Cluster Y because…

To give an accurate recommendation, I need to know:
1. <specific question about the ambiguity>
2. <specific question about the ambiguity>
```

### Step 4 — Return Recommendation

Present the result using this format:

```
## Cluster Deployment Recommendation

**Recommended cluster**: <cluster name> (Subnet <number>)

### Evidence
- Domain: <detected domain>
- eToroDB access: <Yes/No> — <packages found>
- Service type: <Frontend / Backend / Mixed>
- Auth patterns: <STS / API Key / AppSecret / Mixed>

### Traffic Flow
<describe how traffic reaches this service>

### Cross-Cluster Access
<if the service calls other clusters, describe the HA Proxy routing needed>
```

---

## Special Cases

### PCI / WALLET Services
If the project contains any of these indicators, **do not recommend a cluster** — flag for manual review:
- NuGet packages containing `PCI`, `Payment.Card`, `Wallet`
- Controller routes containing `/pci/`, `/wallet/`, `/card/`
- References to PCI-DSS compliance in constitution or specs

Output:
```
⚠ This service appears to be in PCI/WALLET scope.
Cluster deployment requires manual security review.
Contact the infrastructure team for PCI-compliant cluster assignment.
```

### Hybrid Services (DB + Client-Facing)
A service that has BOTH STS-authenticated client-facing endpoints AND direct eToroDB access
goes to **Cluster 11 (BE with eToro DB)** — the DB access requirement takes precedence.
The Front cluster (31) would route to it via the BE cluster (21).

### Worker / Background Services
Services with no HTTP controllers (pure workers, queue consumers) are **backend** by definition.
Apply the eToroDB access check:
- Worker + eToroDB access → Cluster 11
- Worker without eToroDB access → Cluster 21

---

## Decision Tree

Use this tree to walk through the recommendation. The **primary path** uses
four targeted questions (Q1–Q4) to determine the cluster. When running inside
the SpecKit security-review command, these questions are asked interactively.
When running in CI, the answers come from the plan.md Service Security Profile.

If you cannot confidently pick a branch, **ask the user**.

```
START
 │
 ├─ ASK Q1: What is the service domain?
 │   ├─ Trading → ✅ Trading cluster (DONE)
 │   ├─ Money   → ✅ Money cluster (DONE)
 │   └─ Other   → continue ↓
 │
 ├─ Is the service in PCI / WALLET scope?
 │   ├─ YES → ⚠ STOP — manual security review required
 │   └─ NO  → continue ↓
 │
 ├─ ASK Q2: Is this a frontend-facing service? (YES/NO)
 ├─ ASK Q3: Does the service have access to eToro DB? (YES/NO)
 ├─ ASK Q4: Does the service have access to any other database? (YES/NO)
 │
 ├─ Q3 = YES → ✅ Cluster 11 (BE with eToro DB)
 ├─ Q4 = YES → ✅ Cluster 21 (BE)
 ├─ Q2 = YES, no DB access → ✅ Cluster 31 (Front)
 │   └─ Unless massive business logic detected → ✅ Cluster 21 (BE)
 ├─ Q2 = NO, no DB access → ✅ Cluster 21 (BE)
 │
 └─ ❓ Conflicting or insufficient signals → ASK THE USER
```

### Fallback: Code-Based Analysis

When the interactive questions are not available (e.g., automated CI without a
filled plan, or legacy projects), fall back to the code-based analysis in
Steps 1–3 above (detect domain from constitution-team.md, scan .csproj for DB
packages, scan controllers for auth patterns).
