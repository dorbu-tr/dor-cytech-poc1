---
description: "Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts."
---

<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/commands/speckit.tasks.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Setup**: Run the check-prerequisites script from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").
   - **Unix/macOS**: `.specify/scripts/sh/check-prerequisites.sh --json`
   - **Windows (PowerShell)**: `.specify/scripts/powershell/check-prerequisites.ps1 -Json`

2. **Load design documents**: Read from FEATURE_DIR:
   - **Required**: plan.md (tech stack, libraries, structure), spec.md (user stories with priorities)
   - **Optional**: data-model.md (entities), contracts/ (API endpoints), research.md (decisions), quickstart.md (test scenarios)
   - Note: Not all projects have all documents. Generate tasks based on what's available.

3. **Execute task generation workflow**:
   - Load plan.md and extract tech stack, libraries, project structure
   - Load spec.md and extract user stories with their priorities
   - If data-model.md exists: Extract entities and map to technical layers
   - If contracts/ exists: Map endpoints to the Api layer (Phase 5)
   - If research.md exists: Extract decisions for setup tasks (Phase 0)
   - Generate tasks organized by technical layer (see Task Generation Rules below)
   - Distribute spec.md user stories across the appropriate layers — user stories are NOT phases; they are fulfilled across multiple layers
   - Identify parallelizable tasks within each phase
   - Validate task completeness (every layer has all tasks needed for the feature)

4. **Generate tasks.md**: Use `.specify/templates/tasks-template.md` as structure, fill with:
   - Correct feature name from plan.md
   - Phase 0: Planning & Setup (MCP discovery, NuGet discovery)
   - Phase 1: Interfaces / Contracts (all interfaces and DTOs)
   - Phase 2: Domain Layer (enumerations, constants, value objects)
   - Phase 3: Infrastructure Layer (providers, repositories, mock providers)
   - Phase 4: Application Layer (services, health checks, jobs)
   - Phase 5: Api Layer (controllers, bootstrap, request/response DTOs, DI)
   - Phase 6: Testing (component tests, system tests)
   - Phase 7: Polish & Quality Gates (cleanup, README, build/test verification)
   - All tasks must follow the strict checklist format (see Task Generation Rules below)
   - Clear file paths for each task
   - Dependencies section showing phase completion order
   - Parallel execution examples per phase
   - **CRITICAL**: For phases 3–7, copy the `**Agent**:` line from the template exactly as-is, placing it immediately after the `## Phase N: Title` line and before `**Purpose**:`. Do not omit, rename, or reformat it. This line is machine-read by `speckit.implement` to determine which subagent to spawn.

5. **Report**: Output path to generated tasks.md and summary:
   - Total task count
   - Task count per phase
   - Parallel opportunities identified per phase
   - Format validation: Confirm ALL tasks follow the checklist format (checkbox, ID, phase label, file paths)

Context for task generation: $ARGUMENTS

The tasks.md should be immediately executable - each task must be specific enough that an LLM can complete it without additional context.

## Task Generation Rules

**CRITICAL**: Tasks MUST be organized by technical layer, following the phase structure of `.specify/templates/tasks-template.md`.

**Tests are OPTIONAL**: Only generate test tasks if explicitly requested in the feature specification or if user requests TDD approach.

### Checklist Format (REQUIRED)

Every task MUST strictly follow this format:

```text
- [ ] [TaskID] [P?] [Phase] Description with file path
```

**Format Components**:

1. **Checkbox**: ALWAYS start with `- [ ]` (markdown checkbox)
2. **Task ID**: Sequential number (T001, T002, T003...) in execution order
3. **[P] marker**: Include ONLY if task is parallelizable (different files, no dependencies on incomplete tasks within the same phase)
4. **[Phase] label**: REQUIRED for all tasks
   - Format: [P0], [P1], [P2], [P3], [P4], [P5], [P6], [P7] (maps to the technical layer phases)
   - Phase 0 tasks: `[P0]`
   - Phase 1 tasks: `[P1]`
   - Phase 2 tasks: `[P2]`
   - Phase 3 tasks: `[P3]`
   - Phase 4 tasks: `[P4]`
   - Phase 5 tasks: `[P5]`
   - Phase 6 tasks: `[P6]`
   - Phase 7 tasks: `[P7]`
5. **Description**: Clear action with exact file path

**Examples**:

- ✅ CORRECT: `- [ ] T001 [P0] Run MCP discovery for required internal APIs`
- ✅ CORRECT: `- [ ] T011 [P1] Create service interfaces in Application/Services/Interfaces/`
- ✅ CORRECT: `- [ ] T014 [P] [P1] Create request/response DTOs in Api/Dto/`
- ✅ CORRECT: `- [ ] T025 [P3] Create ConfigurationProvider in Infrastructure/Providers/Concrete/`
- ❌ WRONG: `- [ ] Create User model` (missing ID and Phase label)
- ❌ WRONG: `T001 [P1] Create model` (missing checkbox)
- ❌ WRONG: `- [ ] [P1] Create service interface` (missing Task ID)
- ❌ WRONG: `- [ ] T001 [P1] Create service` (missing file path)

### Task Organization

1. **From spec.md user stories** — distribute across layers, do NOT create one phase per story:
   - Interfaces needed for a story → Phase 1
   - Domain enumerations/constants → Phase 2
   - Providers and repositories → Phase 3
   - Services (business logic) → Phase 4
   - Controllers and request/response DTOs → Phase 5
   - Tests covering that story → Phase 6

2. **From Contracts**:
   - Each endpoint → Phase 5 (Api Layer) controller task
   - Request/response DTOs → Phase 5
   - Provider interfaces for external APIs → Phase 1

3. **From Data Model**:
   - Enumerations and constants → Phase 2 (Domain)
   - Repository interfaces → Phase 1
   - Repository implementations → Phase 3 (Infrastructure)
   - Shared data DTOs (Application/Dto/Data/) → Phase 2 or Phase 4 depending on usage

4. **From Setup/Infrastructure**:
   - MCP discovery → Phase 0
   - External provider integrations → Phase 3
   - Bootstrap and DI wiring → Phase 5

### Phase Structure

- **Phase 0**: Planning & Setup (MCP discovery, NuGet research)
- **Phase 1**: Interfaces / Contracts (all interfaces and DTOs — define before implementing)
- **Phase 2**: Domain Layer (enumerations, constants — no external dependencies)
- **Phase 3**: Infrastructure Layer (providers, repositories, mock providers)
- **Phase 4**: Application Layer (services with MonitorWrapper, health checks, jobs)
- **Phase 5**: Api Layer (controllers, bootstrap, request/response DTOs, DI registration)
- **Phase 6**: Testing (component tests, system tests — written; system tests NOT run locally)
- **Phase 7**: Polish & Quality Gates (cleanup, README, build/test verification)
