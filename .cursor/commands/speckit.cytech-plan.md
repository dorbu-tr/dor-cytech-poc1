---
description: Validate the service plan against the Security Agent MVP Ruleset, produce an Auto-approve / Auto-reject / Manual review verdict, and generate the CyTech HLD file.
handoffs:
  - label: Create Tasks
    agent: speckit.tasks
    prompt: Break the plan into tasks
    send: true
  - label: Security Checklist
    agent: speckit.checklist
    prompt: Create a security checklist for this feature
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Validate the service plan against the Security Agent MVP Ruleset, produce
exactly one verdict (**Auto-approve**, **Auto-reject**, or **Manual review**),
and generate a CyTech HLD file from the plan. This command runs after
`/speckit.plan` and before `/speckit.tasks`. At this stage **no code exists
yet** — all evaluation is based on plan.md declarations.

## Operating Constraints

- The security-review skill (`.cursor/skills/core/security-review/SKILL.md`) is
  the **single source of truth** for all rules. Read it first.
- The cluster-deployment skill (`.cursor/skills/core/cluster-deployment/SKILL.md`)
  is the authority for cluster placement validation. Do NOT duplicate its rules.
- The CyTech HLD template (`.specify/templates/cytech-hld-template.md`) defines
  the output structure. Read it before generating the HLD.
- Produce exactly ONE verdict. Never leave the verdict ambiguous.
- Auto-reject takes precedence over Manual review (if any auto-reject criterion
  triggers, the verdict is Auto-reject regardless of manual-review triggers).
- Auto-approve requires ALL criteria to pass with no manual-review triggers.

## Execution Steps

### 1. Setup

Run the check-prerequisites script from repo root and parse JSON for
FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute.

- **Unix/macOS**: `.specify/scripts/sh/check-prerequisites.sh --json`
- **Windows (PowerShell)**: `.specify/scripts/powershell/check-prerequisites.ps1 -Json`

For single quotes in args like "I'm Groot", use escape syntax: e.g
'I'\''m Groot' (or double-quote if possible: "I'm Groot").

### 2. Load Context

Read these files:

- **REQUIRED**: FEATURE_DIR/plan.md — primary evaluation input
- **REQUIRED**: FEATURE_DIR/spec.md — feature requirements
- **REQUIRED**: `.specify/memory/constitution.md` — core constitution
- **REQUIRED**: `.specify/memory/constitution-team.md` — team constitution
- **REQUIRED**: `.cursor/skills/core/security-review/SKILL.md` — the ruleset
- **REQUIRED**: `.cursor/skills/core/cluster-deployment/SKILL.md` — cluster rules
- **REQUIRED**: `.specify/templates/cytech-hld-template.md` — HLD output template
- **IF EXISTS**: FEATURE_DIR/data-model.md — entities and relationships
- **IF EXISTS**: FEATURE_DIR/contracts/ — API specifications

### 3. Ask Cluster Determination Questions

After loading context and BEFORE extracting security signals from plan.md,
ask the user 4 targeted questions to determine the correct cluster placement.
These questions feed directly into the cluster-deployment skill's decision tree
and the security-review skill's Interactive Cluster Determination section.

**Ask in order**:

1. **Q1**: "What is the service domain?" — Trading / Money / Other
   - If Trading → Trading cluster, record answer, skip to step 4
   - If Money → Money cluster, record answer, skip to step 4
   - If Other → continue to Q2

2. **Q2**: "Is this a frontend-facing service? (endpoints accessed by end-users
   with STS tokens)" — YES / NO

3. **Q3**: "Does the service have direct access to eToro DB? (SQL connection to
   eToro production databases)" — YES / NO

4. **Q4**: "Does the service have access to any other database? (non-eToro
   databases, team-owned DBs, third-party data stores)" — YES / NO

**Map answers to cluster recommendation** using the decision table from the
security-review skill's Interactive Cluster Determination section:

| Q3 (eToro DB?) | Q4 (Other DB?) | Q2 (Frontend?) | Cluster |
|:-:|:-:|:-:|---|
| YES | * | * | Cluster 11 (BE with eToro DB) |
| NO | YES | * | Cluster 21 (BE) |
| NO | NO | YES | Cluster 31 (Front) |
| NO | NO | NO | Cluster 21 (BE) |

**After determining the recommended cluster**:

1. Present the recommendation to the user and ask for confirmation
2. If plan.md already has a Target Cluster declared, compare it with the
   recommendation:
   - Match → proceed
   - Mismatch → warn the user and ask if they want to update the plan
3. Use the confirmed cluster as input for the rest of the evaluation

### 4. Extract Security Signals from Plan

Parse plan.md for the **Service Security Profile** section and extract:

| Signal | Where to Find in plan.md |
|--------|--------------------------|
| Data classification | Service Security Profile → Data Classification |
| Service type | Service Security Profile → Service Type |
| Target cluster | Service Security Profile → Target Cluster |
| eToroDB access | Service Security Profile → eToroDB Access |
| PII handling | Service Security Profile → PII Handling |
| Sensitive dependencies | Service Security Profile → Sensitive Dependencies |
| Authentication model | Service Security Profile → Authentication Model |
| External-facing endpoints | Service Security Profile → External-Facing Endpoints |
| PCI scope | Service Security Profile → PCI Scope |

**If the Service Security Profile section is missing or incomplete**:

1. STOP and inform the user that the plan is missing required security
   declarations.
2. List which fields are missing.
3. Instruct the user to update plan.md with the Service Security Profile
   section (format defined in the security-review skill).
4. Do NOT proceed with evaluation until all fields are present.

### 5. Run Cluster Placement Validation

Use the interactive question answers from step 3 as the **primary input** for
cluster placement validation. The cluster-deployment skill's decision tree
validates the recommendation, but the Q&A responses provide the evidence.

1. **Domain** (from Q1): Trading → Trading cluster, Money → Money cluster,
   Other → continue.
2. **PCI/WALLET check**: If plan declares PCI Scope = Yes → escalate to Manual
   review.
3. **eToroDB access** (from Q3): If YES → recommended cluster is 11.
4. **Other DB access** (from Q4): If YES (and Q3=NO) → recommended cluster is 21.
5. **Frontend-facing** (from Q2): If YES and no DB access → Cluster 31.
   Unless plan describes massive business logic (complex orchestration, 3+ API
   providers, rule engines, heavy transformation) → Cluster 21 (BE).
6. **Backend** (Q2=NO, no DB): → Cluster 21 (BE).

**Compare** the confirmed cluster (from step 3) against the plan's declared
Target Cluster:
- Match → PASS
- Declared cluster is MORE restrictive than needed → PASS (conservative is OK)
- Declared cluster is LESS restrictive than needed → Auto-Reject (R12)
- Conflicting or ambiguous signals (equivalent to cluster-deployment Step 3b) →
  escalate entire verdict to Manual Review

### 6. Evaluate Auto-Approve Criteria

Check every criterion from the security-review skill's "Auto-Approve Criteria"
section against the extracted signals. ALL must pass:

1. Data classification is Public or Internal (with conditions)
2. No direct eToroDB access (or not on restricted list)
3. No PII storage/processing
4. No sensitive dependencies
5. Authentication present on private endpoints
6. Logging discipline confirmed (no PII/secrets in logs)
7. Cluster placement matches (from step 5)
8. Service matches a qualifying type

Mark each criterion PASS / FAIL / UNKNOWN.

### 7. Evaluate Auto-Reject Criteria

Check plan-stage reject criteria (R1, R4, R6, R11, R12) from the
security-review skill's "Auto-Reject Criteria" section:

- R1: Plan declares PII logging without masking
- R4: Plan shows sensitive endpoint without auth
- R6: Data classification mismatch (accesses higher-sensitivity data than
  declared)
- R11: Plan describes endpoints with user input but no validation mentioned
- R12: Cluster placement mismatch (from step 5)

If ANY trigger → verdict is **Auto-reject**.

### 8. Evaluate Manual Review Triggers

If no auto-reject criteria triggered, check manual review triggers from the
security-review skill:

- PCI scope declared
- Auth/authz module being created or modified
- Mixed or unclear data classification
- Trading or Money cluster
- Ambiguous external-facing endpoints
- Confidential or Restricted data classification
- Cluster-deployment conflict (from step 5)

If ANY trigger → verdict is **Manual review**.

### 9. Classify Verdict

Apply this precedence:

1. If any Auto-Reject criterion triggered → **Auto-reject**
2. If any Manual Review trigger fired → **Manual review**
3. If all Auto-Approve criteria passed → **Auto-approve**

### 10. Generate security-review.md

Create `FEATURE_DIR/security-review.md` following the verdict output format
defined in the security-review skill. Include:

- **Cluster Determination** subsection showing each question (Q1-Q4), the
  user's answer, and the resulting cluster recommendation
- Service Security Profile summary table with PASS/FAIL per attribute
- Full criteria evaluation table with result and evidence for each criterion
- Verdict heading: `## Verdict: Auto-approve` or `## Verdict: Auto-reject` or
  `## Verdict: Manual review`
- If Auto-reject: `## Rejection Reasons` with numbered list of violations,
  evidence, and remediation steps
- If Manual review: `## Manual Review Items` with numbered list of triggers,
  evidence, and who to contact

### 11. Generate CyTech HLD

After producing the security-review.md verdict, generate a CyTech HLD file at
`FEATURE_DIR/hld.md` using the template at `.specify/templates/cytech-hld-template.md`.

Populate ALL sections from plan.md, cluster decision, and security evaluation:

#### Section Mapping (plan.md → HLD)

**Service Metadata** (from plan.md header + constitution):
- Service Name → from plan.md branch/feature name
- Service Repository → from git remote or constitution
- Domain → from Q1 answer or team constitution
- Owner (R&D team) → from constitution-team.md header
- Author → from git config or ask user
- Target Environments → default `QA, INT, STG, PROD` unless plan says otherwise
- Main Technology → `.NET` (from template)
- Service Type → from Service Security Profile → Service Type

**Section 1 - Architecture Overview**:
- Classification → map from Service Security Profile:
  - Frontend-facing + STS → `public-facing`
  - Backend + API Key/AppSecret → `internal-backend`
  - Worker/Cron → `worker`
- AKS Service → `Yes` (all services from this template are AKS)
- External Dependencies → from plan.md Sensitive Dependencies + API Discovery

**Section 2 - Deployment**:
- Health Endpoint → `/healthcheck` (from template default)
- HA Required → `Yes` for PROD, `No` for QA
- Cluster Assignments → from cluster-deployment Q1-Q4 answers:
  - PROD cluster → the confirmed cluster from security review
  - Other envs → auto-resolve or same cluster

**Section 5 - Security** (three sub-tables from security-review skill):

Populate all three sub-tables as defined in the security-review skill's
"CyTech HLD Generation" section:

- **5.1 Data Classification (D1-D8)**: Fill Value column from plan.md Service
  Security Profile. Apply the HLD template's validation rules. Set Result to
  PASS/FAIL/REVIEW based on rules. Fill Evidence with the specific plan.md
  content evaluated.

- **5.2 Security Criteria Evaluation (A1-A8, R1, R4, R6, R11, R12)**: Fill
  Value from plan.md. Result = the evaluation outcome from steps 6-7. Evidence
  = the specific plan.md declaration that was checked. If additional signals
  are discovered at runtime that don't map to predefined rows, add `DYN-` rows
  with all columns populated.

- **5.3 Manual Review Triggers (M1-M8)**: Set Detected = YES/NO from step 8
  evaluation. Evidence = the plan.md content that triggered it. Add `DYN-M-`
  rows for runtime-discovered triggers.

**Section 7.3 - Security Agent Decision Override**:
- Decision → the verdict from step 9 (Auto-approve / Auto-reject / Manual review)
- Reason → summary from security-review.md evaluation
- Reviewer → if Manual review, specify security architect contact

**All other sections** (Scalability, Monitoring, etc.):
- Fill from plan.md where data exists
- Mark as `<TBD - to be filled during implementation>` where plan has no info
- Section 6 Monitoring: PII Redaction must match Section 5 PII Level

### 12. Gate Behavior

- **Auto-approve**: Display the verdict, then present the handoff buttons
  (Create Tasks / Security Checklist). The developer can proceed.
- **Auto-reject**: Display the verdict with all rejection reasons and
  remediation guidance. **STOP** — inform the user they must fix the plan and
  re-run `/speckit.cytech-plan`. Do NOT present handoff buttons.
- **Manual review**: Display the verdict with all flagged items. **STOP** —
  inform the user they must obtain security architect sign-off and confirm
  before proceeding. Ask: "Has the security architect approved? (yes/no)".
  Only present handoff buttons after confirmation.

### 13. Shadow Mode

Check if the project is in shadow mode (Phase 1 rollout). In shadow mode:

- The verdict is a **recommendation only**
- The command does NOT block progression
- Always present handoff buttons regardless of verdict
- Prepend verdict with: "**[SHADOW MODE]** This verdict is advisory only.
  Human validation is required."

Shadow mode can be indicated by a `security_review_mode: shadow` key in
constitution or plan.md. Default is shadow mode if no key is found.

## Key Rules

- Use absolute paths
- ERROR if plan.md is missing or has no Service Security Profile
- Never produce an ambiguous verdict
- Never duplicate cluster-deployment rules — reference the skill
- Auto-reject takes precedence over Manual review
- All evaluation at this stage is from plan.md — no code scanning
- The HLD file (hld.md) MUST be generated after the verdict — it captures the
  complete evaluation results for CI re-validation
