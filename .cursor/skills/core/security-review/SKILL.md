---
name: security-review
description: >-
  Security Agent MVP Ruleset for evaluating services against auto-approve,
  auto-reject, and manual-review criteria. Use when validating a service plan
  for security compliance, checking data classification, cluster placement,
  authentication, PII handling, dependency sensitivity, or producing a security
  review verdict. Triggers on any work involving security review, CyTechPlan
  validation, service approval, or security gate evaluation.
---

# Security Agent MVP Ruleset

## Overview

Every eToro service must pass a security review before proceeding to
implementation. This skill defines the complete ruleset used by both the local
SpecKit command (`/speckit.cytech-plan`) and the CI Cytech agent GitHub
Action. The review evaluates the service **plan.md** (no code exists at this
stage) and produces exactly one verdict:

- **Auto-approve** — service proceeds, no explanation needed
- **Auto-reject** — service is blocked; output explains every failing criterion and remediation
- **Manual review** — service is flagged; output explains which items need security architect sign-off

---

## Interactive Cluster Determination

Before evaluating the security profile, the evaluator MUST ask the user
four questions to determine the correct cluster placement. These
questions replace manual field-guessing and feed directly into the
cluster-deployment skill's decision tree.

### Questions (ask in order)

**Q1: What is the service domain?**
- Trading
- Money
- Other

> If Trading --> Trading cluster (DONE, skip remaining questions)
> If Money --> Money cluster (DONE, skip remaining questions)
> If Other --> continue to Q2

**Q2: Is this a frontend-facing service?**
- YES = service has client-facing endpoints (STS/user tokens)
- NO = backend-only, worker, or internal service

**Q3: Does the service have access to eToro DB?**
- YES = direct SQL connection to eToro production databases
- NO = no direct database access to eToro DB

**Q4: Does the service have access to any other database?**
- YES = connects to non-eToro databases (third-party, team-owned, etc.)
- NO = no database access at all

### Cluster Decision (for domain = Other)

- DB Access (Q3=YES or Q4=YES) --> Cluster 11 (BE with eToro DB) if Q3=YES,
  otherwise Cluster 21 (BE)
- Frontend-facing (Q2=YES, Q3=NO, Q4=NO) --> Cluster 31 (Front)
- Backend (Q2=NO, Q3=NO, Q4=NO) --> Cluster 21 (BE)

Simplified:

| Q2 (Frontend?) | Q3 (eToro DB?) | Q4 (Other DB?) | Cluster |
|:-:|:-:|:-:|---|
| * | YES | * | Cluster 11 (BE with eToro DB) |
| * | NO | YES | Cluster 21 (BE) |
| YES | NO | NO | Cluster 31 (Front) |
| NO | NO | NO | Cluster 21 (BE) |

---

## Data Classification Levels

| Level | Description | Examples | Auto-Approve Eligible? |
|-------|-------------|----------|------------------------|
| **Public** | Openly available, no risk if distributed | Public announcements, public portfolio, market data | Yes — must be intentionally declared as public in plan |
| **Internal** | Default for non-Restricted, non-Confidential data not explicitly made public | Internal reports, non-sensitive operational data | Yes — only if no sensitive dependencies and no human-facing exposure |
| **Confidential** | Disclosure could cause meaningful financial or reputational damage | IP, architecture docs, topology, IP addresses, hostnames, customer/employee PII (name, address, email, phone) | No — Manual Review required, needs security architect sign-off |
| **Restricted** | Significant adverse impact if disclosed; often regulated | Credentials, session tokens, bank account numbers, passport/national ID/driving license numbers | No — any unauthenticated exposure = Auto-Reject; authenticated access = Manual Review |

---

## Auto-Approve Criteria

A service is automatically approved if **ALL** of the following are true:

### Data & Privacy
1. **Data classification is Public or Internal**
   - Frontend-facing: handles only Internal or Public data (e.g., public portfolio, public market data)
   - Backend-only: not involved in PII / sensitive write actions like trading/money
2. **No direct access to eToro DB** or any database on the restricted production database list
3. **No PII in any sensitive form** — no storage, no processing of sensitive PII
4. **No sensitive dependencies** — no direct calls to services that handle sensitive/confidential data or logic

### Authentication & Logging
5. **Authentication present** — if the service exposes any customer private data endpoint, authentication is present and documented in the plan
6. **No PII or secrets in logs** — plan confirms logging discipline with `[SensitiveData]` annotations; no PII or secrets written to logs in clear text

### Cluster Placement
7. **Cluster placement correctly declared and matches service type** — validated using the interactive questions (Q1–Q4) from the "Interactive Cluster Determination" section above and the `cluster-deployment` skill (`.cursor/skills/core/cluster-deployment/SKILL.md`):
   - Trading domain (Q1) → Trading cluster
   - Money domain (Q1) → Money cluster
   - eToro DB access (Q3=YES) → Cluster 11 (BE with eToro DB)
   - Other DB access (Q4=YES) → Cluster 21 (BE)
   - Frontend-facing, no DB (Q2=YES) → Cluster 31 (Front)
   - Backend, no DB (Q2=NO) → Cluster 21 (BE)

> **Cluster validation**: The interactive questions (Q1–Q4) are the primary
> input for cluster determination. The `cluster-deployment` skill's decision
> tree validates the recommendation. Do NOT duplicate cluster rules here.
> Compare the recommendation against the plan's declared cluster. A mismatch
> where the declared cluster is less restrictive than required is an
> Auto-Reject. If the cluster-deployment skill encounters conflicting/ambiguous
> signals (its Step 3b), escalate to Manual Review.

### Service Type Qualification
8. **Service matches one of these qualifying types**:

| Type | Description |
|------|-------------|
| Stateless service | No persistence layer — no DB, no cache, no file storage; purely computational |
| Internal tooling | Only accessible within the internal dev environment, not reachable from any production cluster |
| Wrapper / proxy | Thin pass-through layer that adds no data processing, only routing |
| Approved twin | Structurally identical to a previously manually approved service (same cluster, same data classification, same auth pattern) |
| Config-only change | No code change, only environment variable or feature flag update with no data classification impact |
| QA / mock service | Explicitly scoped to non-production environments only, with no access to real data |

---

## Auto-Reject Criteria

A service is automatically rejected if **ANY** of the following are true:

| # | Criterion | What to Check |
|---|-----------|---------------|
| R1 | PII written in clear text to logs | Plan declares logging of PII fields without `[SensitiveData]` Mask/Hash annotations |
| R2 | Secrets / credentials hard-coded in source code | Checked post-commit: API keys, connection strings, passwords, tokens in `.cs`, `.json`, `.config` files |
| R3 | Secrets present in git history (active secrets) | Scan PR commits for leaked secrets that are still active |
| R4 | Sensitive endpoint exposed without authentication | Endpoint returning private portfolio data, user financial data with no auth layer declared in plan |
| R5 | Developer implementation deviates from approved spec/plan | Code at commit stage doesn't match the declared design in the plan (post-commit check) |
| R6 | Data classification mismatch | Service accesses data of higher sensitivity than declared in the plan / cluster classification |
| R7 | Known vulnerable dependencies | Service uses a library with a critical/high CVE (checked against NVD/OSV at commit time) |
| R8 | Hardcoded internal IPs, hostnames, or connection strings | Exposes infrastructure topology in code — must be in CCM/KV |
| R9 | Overly permissive IAM / RBAC roles | Service declares wildcard permissions (e.g., `*` on resource policies) instead of least-privilege |
| R10 | Sensitive data returned in error messages | Stack traces, internal paths, or PII visible in API error responses |
| R11 | Missing input validation on user-supplied data | No sanitization declared for endpoints accepting file uploads or free-text input |
| R12 | Cluster placement mismatch | Declared cluster is less restrictive than what the `cluster-deployment` skill recommends |

**Plan-stage checks** (R1, R4, R6, R11, R12): Evaluated from plan.md declarations before any code exists.
**Post-commit checks** (R2, R3, R5, R7, R8, R9, R10): Evaluated from actual source code after implementation.

---

## Manual Review Triggers

Everything that does not clearly fall into Auto-Approve or Auto-Reject goes to
manual review. This includes but is not limited to:

| Trigger | Why |
|---------|-----|
| PCI scope | Requires PCI-DSS compliant infrastructure and dedicated security review |
| Auth/authz module changes | Any service implementing or modifying an Authentication / Authorization module |
| Unclear or mixed data classification | Cannot determine classification from plan declarations alone |
| Trading or Money cluster services | Access to trading or money clusters requires elevated review |
| Ambiguous external-facing endpoints | Data sensitivity of external endpoints is unclear |
| Medium/high LLM risk score | When automated risk assessment yields medium or high risk |
| Confidential data classification | Includes PII — requires security architect sign-off |
| Restricted data with authenticated access | Authenticated access to restricted data still requires manual review |
| Cluster-deployment skill conflict | The `cluster-deployment` skill cannot confidently determine the cluster (Step 3b) |

---

## Review Stages

The security review runs at two stages in the service lifecycle:

### Stage 1: Planning / HLD Review

**When**: After `/speckit.plan` generates plan.md, before any code exists.
**Input**: plan.md, spec.md, data-model.md, contracts/ (all from `specs/` directory).
**Who acts**: Security Agent (local command or Cytech agent GitHub Action).

**What's checked**:
- Data classification declared and consistent
- Cluster placement matches service type (via `cluster-deployment` skill)
- Authentication documented for all private endpoints
- PII handling declared (or confirmed as None)
- Sensitive dependencies listed
- Service type qualification identified
- No auto-reject criteria triggered from plan declarations (R1, R4, R6, R11, R12)

### Stage 2: Post-Commit Review

**When**: After implementation, when code is pushed to GitHub.
**Input**: Source code under `src/`, `Tests/`, config files, plus the approved plan.md.
**Who acts**: Cytech agent GitHub Action.

**What's checked**:
- Code matches spec/plan — no deviation from approved design (R5)
- No secrets in code or git history (R2, R3)
- No PII in log statements without annotations (R1)
- Auth implemented as declared in plan (R4)
- Input validation present on user-supplied data (R11)
- No sensitive data in error responses (R10)
- No hardcoded IPs/hostnames/connection strings (R8)
- No vulnerable dependencies with critical/high CVEs (R7)
- No overly permissive IAM/RBAC (R9)
- Cluster placement in deployment config matches plan's security review (R12)

---

## Service Security Profile

The plan.md **must** include a Service Security Profile section with these
mandatory declarations. This is the primary input for the security review at
the planning stage (no code exists yet):

```markdown
### Service Security Profile

- **Data Classification**: [Public / Internal / Confidential / Restricted]
- **Service Type**: [Stateless / Internal tooling / Wrapper-proxy / Approved twin / Config-only / QA-mock / Other]
- **Target Cluster**: [Front (31) / BE (21) / BE with eToroDB (11) / Trading / Money]
- **eToroDB Access**: [Yes / No] — if Yes, list databases
- **PII Handling**: [None / Read-only / Storage / Processing] — if any, list data fields
- **Sensitive Dependencies**: [None / List services that handle sensitive/confidential data]
- **Authentication Model**: [STS client-facing / API Key backend / AppSecret / Mixed / None]
- **External-Facing Endpoints**: [Yes / No] — if Yes, list endpoints and data sensitivity
- **PCI Scope**: [Yes / No]
```

---

## Verdict Output Format

The security review always produces a `security-review.md` file in the feature
directory with this structure:

```markdown
# Security Review: [Feature Name]

**Date**: [DATE]
**Plan**: [link to plan.md]
**Mode**: [Shadow / Autonomous / Expanded]

## Service Security Profile

| Attribute | Declared Value | Assessment |
|-----------|---------------|------------|
| Data Classification | Internal | PASS |
| Service Type | Stateless | PASS |
| Target Cluster | BE (21) | PASS — matches cluster-deployment recommendation |
| eToroDB Access | No | PASS |
| PII Handling | None | PASS |
| Sensitive Dependencies | None | PASS |
| Authentication | STS client-facing | PASS |
| External-Facing | Yes — /api/v1/portfolio | PASS — public data only |
| PCI Scope | No | PASS |

## Criteria Evaluation

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| A1 | Data classification Public/Internal | PASS | Declared as Internal |
| A2 | No eToroDB access | PASS | No DB packages declared |
| ... | ... | ... | ... |

## Verdict: Auto-approve

(or)

## Verdict: Auto-reject

### Rejection Reasons
1. **R4 — Sensitive endpoint without auth**: Endpoint `/api/v1/user-data`
   returns PII but no authentication declared.
   **Remediation**: Add STS authentication to all endpoints returning user data.

(or)

## Verdict: Manual review

### Manual Review Items
1. **PCI Scope**: Service declares PCI scope. Requires security architect
   sign-off for PCI-compliant cluster assignment.
   **Contact**: Infrastructure security team.
```

---

## CyTech HLD Generation

After producing the security-review verdict, the evaluator MUST generate a
CyTech HLD file (`hld.md`) in the feature directory. This file follows the
`cytech-hld-template.md` structure (`.specify/templates/cytech-hld-template.md`)
and is the artifact that the GitHub Action re-validates on PR.

### Section 5 Structure (three sub-tables)

The HLD Security section (Section 5) MUST contain three sub-tables that
together cover every validation defined in this skill:

**5.1 Data Classification** — Standard HLD template fields (D1-D8) with the
HLD template's own validation rules applied (third-party due diligence chain,
PII escalation levels, mandatory fields).

| # | Field | Value | Result | Rule Applied | Evidence |
|---|-------|-------|--------|-------------|----------|
| D1 | Third-Party Interaction | from plan | PASS/FAIL | If Yes → due diligence must be approved, else auto-reject | |
| D2 | Third-Party Due Diligence | from plan (if D1=Yes) | PASS/FAIL/N/A | Must be Yes if D1=Yes, else auto-reject | |
| D3 | Customer / User Identifiers | from plan | PASS/FAIL | If Yes → list identifier types | |
| D4 | Rate Limit (req/s) | from plan | PASS/FAIL | Must be numeric, must not be blank | |
| D5 | PII Level | map from PII Handling | PASS/FAIL/REVIEW | None=PASS; Elevated=manual review; Yes=mandatory meeting | |
| D6 | Financial / Trading Data | from domain + data classification | PASS/FAIL/REVIEW | Read-write + non-Trading cluster = manual review | |
| D7 | Auth / Authz Artifacts | from Authentication Model | PASS/FAIL | Must not be blank | |
| D8 | Configuration System | from plan or default CCM | PASS/FAIL | Must be declared | |

**5.2 Security Criteria Evaluation** — One row per auto-approve criterion
(A1-A8) and one row per plan-stage auto-reject criterion (R1, R4, R6, R11,
R12). Each row maps to a specific Service Security Profile field in plan.md.

| # | Criterion | Source Field in plan.md | Value | Result | Consequence if FAIL | Evidence |
|---|-----------|----------------------|-------|--------|-------------------|----------|
| A1 | Data classification = Public or Internal | Data Classification | | PASS/FAIL | Blocks auto-approve; Confidential→manual, Restricted→reject if unauth | |
| A2 | No direct eToroDB access | eToroDB Access | | PASS/FAIL | Blocks auto-approve | |
| A3 | No PII storage/processing | PII Handling | | PASS/FAIL | Blocks auto-approve | |
| A4 | No sensitive dependencies | Sensitive Dependencies | | PASS/FAIL | Blocks auto-approve | |
| A5 | Auth present on private endpoints | Authentication Model + External-Facing Endpoints | | PASS/FAIL | Blocks auto-approve; missing auth on sensitive endpoint→R4 reject | |
| A6 | No PII/secrets in logs | plan logging declarations | | PASS/FAIL | Blocks auto-approve; PII without masking→R1 reject | |
| A7 | Cluster placement matches service type | Target Cluster vs Q1-Q4 recommendation | | PASS/FAIL | Blocks auto-approve; less restrictive→R12 reject | |
| A8 | Service matches qualifying type | Service Type | | PASS/FAIL | Blocks auto-approve; type=Other→manual review | |
| R1 | PII in logs without masking | plan logging declarations | | PASS/FAIL | **Auto-reject** | |
| R4 | Sensitive endpoint without auth | External-Facing Endpoints + Authentication Model | | PASS/FAIL | **Auto-reject** | |
| R6 | Data classification mismatch | Data Classification vs actual data access patterns | | PASS/FAIL | **Auto-reject** | |
| R11 | Missing input validation | Endpoint declarations (file upload, free-text) | | PASS/FAIL | **Auto-reject** | |
| R12 | Cluster placement mismatch | Target Cluster vs cluster-deployment recommendation | | PASS/FAIL | **Auto-reject** | |

**5.3 Manual Review Triggers** — One row per manual review trigger (M1-M8).
Each row maps to a plan.md field or combination of fields.

| # | Trigger | Source Field in plan.md | Detected | Evidence |
|---|---------|----------------------|----------|----------|
| M1 | PCI scope | PCI Scope | YES/NO | |
| M2 | Auth/authz module changes | Service description in plan | YES/NO | |
| M3 | Unclear or mixed data classification | Data Classification | YES/NO | |
| M4 | Trading or Money cluster | Target Cluster / Q1 answer | YES/NO | |
| M5 | Ambiguous external-facing endpoints | External-Facing Endpoints | YES/NO | |
| M6 | Confidential data classification | Data Classification | YES/NO | |
| M7 | Restricted data with authenticated access | Data Classification + Auth Model | YES/NO | |
| M8 | Cluster-deployment skill conflict | Q1-Q4 vs plan declared cluster | YES/NO | |

### Dynamic Rows

At runtime, the evaluator MUST add rows for any signals discovered in plan.md
that don't map to a predefined criterion. These use prefixes:
- `DYN-` for criteria rows (in 5.2) — e.g., undeclared dependency found in
  contracts/ but missing from Sensitive Dependencies
- `DYN-M-` for trigger rows (in 5.3) — e.g., plan mentions "payment gateway"
  but PCI Scope = No

Dynamic rows MUST populate all columns including Consequence/Evidence so the
GitHub Action can evaluate them independently.

### Verdict Derivation

The three sub-tables determine the verdict:
- Any R-row FAIL in 5.2 → **Auto-reject**
- Any M-row TRIGGERED in 5.3 → **Manual review** (if no auto-reject)
- All A-rows PASS in 5.2, no M-rows triggered → **Auto-approve**

The HLD is generated from plan.md — it is a structured reformatting of the
plan's security profile combined with the evaluation results, NOT new
information.

---

## Rollout Phases

| Phase | Mode | Behavior |
|-------|------|----------|
| **Phase 1** (current) | Shadow | Agent recommends approve/reject but humans validate every decision. Results tracked in dashboard. Verdict does NOT block. |
| **Phase 2** | Autonomous | Once KPIs are met (accuracy threshold TBD), agent takes auto-approve/reject autonomously for clearly categorized services. |
| **Phase 3** | Expanded | Expand auto-approve criteria based on observed patterns. |

The mode is controlled by a configuration value that can be set in the
constitution or plan. In shadow mode, GitHub Action status checks are set to
non-required (advisory only).
