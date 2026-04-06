---
description: "Execute the implementation plan by processing and executing all tasks defined in tasks.md"
---

<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/commands/speckit.implement.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. Run the check-prerequisites script from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").
   - **Unix/macOS**: `.specify/scripts/sh/check-prerequisites.sh --json --require-tasks --include-tasks`
   - **Windows (PowerShell)**: `.specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks`

2. **Check checklists status** (if FEATURE_DIR/checklists/ exists):
   - Scan all checklist files in the checklists/ directory
   - For each checklist, count:
     - Total items: All lines matching `- [ ]` or `- [X]` or `- [x]`
     - Completed items: Lines matching `- [X]` or `- [x]`
     - Incomplete items: Lines matching `- [ ]`
   - Create a status table:

     ```text
     | Checklist | Total | Completed | Incomplete | Status |
     |-----------|-------|-----------|------------|--------|
     | ux.md     | 12    | 12        | 0          | ✓ PASS |
     | test.md   | 8     | 5         | 3          | ✗ FAIL |
     | security.md | 6   | 6         | 0          | ✓ PASS |
     ```

   - Calculate overall status:
     - **PASS**: All checklists have 0 incomplete items
     - **FAIL**: One or more checklists have incomplete items

   - **If any checklist is incomplete**:
     - Display the table with incomplete item counts
     - **STOP** and ask: "Some checklists are incomplete. Do you want to proceed with implementation anyway? (yes/no)"
     - Wait for user response before continuing
     - If user says "no" or "wait" or "stop", halt execution
     - If user says "yes" or "proceed" or "continue", proceed to step 3

   - **If all checklists are complete**:
     - Display the table showing all checklists passed
     - Automatically proceed to step 3

3. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints
   - **IF EXISTS**: Read quickstart.md for integration scenarios

4. **Project Setup Verification**:
   - **REQUIRED**: Create/verify ignore files based on actual project setup:

   **Detection & Creation Logic**:
   - Check if the following command succeeds to determine if the repository is a git repo (create/verify .gitignore if so):

     ```sh
     git rev-parse --git-dir 2>/dev/null
     ```

   - Check if Dockerfile* exists or Docker in plan.md → create/verify .dockerignore
   - Check if .eslintrc* exists → create/verify .eslintignore
   - Check if eslint.config.* exists → ensure the config's `ignores` entries cover required patterns
   - Check if .prettierrc* exists → create/verify .prettierignore
   - Check if .npmrc or package.json exists → create/verify .npmignore (if publishing)
   - Check if terraform files (*.tf) exist → create/verify .terraformignore
   - Check if .helmignore needed (helm charts present) → create/verify .helmignore

   **If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only
   **If ignore file missing**: Create with full pattern set for detected technology

   **Common Patterns by Technology** (from plan.md tech stack):
   - **Node.js/JavaScript/TypeScript**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
   - **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
   - **Java**: `target/`, `*.class`, `*.jar`, `.gradle/`, `build/`
   - **C#/.NET**: `bin/`, `obj/`, `*.user`, `*.suo`, `packages/`
   - **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
   - **Ruby**: `.bundle/`, `log/`, `tmp/`, `*.gem`, `vendor/bundle/`
   - **PHP**: `vendor/`, `*.log`, `*.cache`, `*.env`
   - **Rust**: `target/`, `debug/`, `release/`, `*.rs.bk`, `*.rlib`, `*.prof*`, `.idea/`, `*.log`, `.env*`
   - **Kotlin**: `build/`, `out/`, `.gradle/`, `.idea/`, `*.class`, `*.jar`, `*.iml`, `*.log`, `.env*`
   - **C++**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.so`, `*.a`, `*.exe`, `*.dll`, `.idea/`, `*.log`, `.env*`
   - **C**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.a`, `*.so`, `*.exe`, `Makefile`, `config.log`, `.idea/`, `*.log`, `.env*`
   - **Swift**: `.build/`, `DerivedData/`, `*.swiftpm/`, `Packages/`
   - **R**: `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, `*.Rproj`, `packrat/`, `renv/`
   - **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

   **Tool-Specific Patterns**:
   - **Docker**: `node_modules/`, `.git/`, `Dockerfile*`, `.dockerignore`, `*.log*`, `.env*`, `coverage/`
   - **ESLint**: `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`
   - **Prettier**: `node_modules/`, `dist/`, `build/`, `coverage/`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
   - **Terraform**: `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`
   - **Kubernetes/k8s**: `*.secret.yaml`, `secrets/`, `.kube/`, `kubeconfig*`, `*.key`, `*.crt`

5. Parse tasks.md structure and extract:
   - **Task phases**: Setup, Tests, Core, Integration, Polish
   - **Task dependencies**: Sequential vs parallel execution rules
   - **Task details**: ID, description, file paths, parallel markers [P]
   - **Execution flow**: Order and dependency requirements

6. **Multi-Agent Delegation** (for eToro .NET API services):

   When tasks.md contains phased tasks for an eToro API service, delegate to specialized subagents. Each subagent runs in its **own isolated context window**, reading only the skills relevant to its domain.

   **Detection:** For each `## Phase N:` header in tasks.md, read the line immediately following the header. If it matches `**Agent**: <name>`, that phase is delegated to the named subagent. If no `**Agent**:` line is present (phases 0–2), the orchestrator handles the phase directly.

   **Delegation Flow:**

   | Phase | Agent line present? | Delegate To | Mode |
   |-------|---------------------|-------------|------|
   | 0–2 | No | Orchestrator (you) | Direct |
   | 3 | Yes (`infra-developer`) | `infra-developer` | FOREGROUND |
   | 4 | Yes (`app-developer`) | `app-developer` | FOREGROUND |
   | 5 | Yes (`api-developer`) | `api-developer` | FOREGROUND |
   | 6 component tests | Yes (`test-developer`) | `test-developer` | FOREGROUND |
   | 6 system tests | Yes (`test-developer`) | `test-developer` | BACKGROUND (write-only, do not run locally) |
   | 7 | No | Orchestrator (you) | Direct |

   **How to delegate:**
   - Use your IDE's sub-agent or task delegation mechanism to spawn a specialized agent for each phase
   - When delegating, **ALWAYS** start the prompt with:
     1. "FIRST: Read your core agent file at `.codex/agents/core/<name>.md` — it lists which skills to load"
     2. "AND: If `.codex/agents/team/<name>.md` exists, read it too — it extends the core agent with team-specific skills"
     3. "THEN: Read both constitution files at `.specify/memory/constitution.md` and `.specify/memory/constitution-team.md`"
     4. "FINALLY: Implement the following tasks..." (include a context summary from the previous phase: which interfaces were created, which providers exist, etc.)
   - The agent files are the single source of truth for which skills to load — do not enumerate skills in the delegation prompt
   - **Foreground** subagents block until done (sequential phases where output feeds the next)
   - **Background** subagents run simultaneously (system tests run in background after component tests pass)
   - After all subagents complete, orchestrator runs `dotnet build` + `dotnet test --filter Category=ComponentTests`

   **Context isolation per subagent:**
   - Each subagent reads only its own agent file(s) and the skills listed there
   - No testing patterns in the infrastructure agent, no README patterns in the test agent
   - This dramatically reduces context window usage (~17K tokens vs ~85K tokens)

   **Fallback:** If sub-agent delegation is not supported by your IDE or the project is not an eToro .NET API service, fall back to direct execution (steps 7-8 below).

7. Execute implementation following the task plan:
   - **Phase-by-phase execution**: Complete each phase before moving to the next
   - **Respect dependencies**: Run sequential tasks in order, parallel tasks [P] can run together  
   - **Follow TDD approach**: Execute test tasks before their corresponding implementation tasks
   - **File-based coordination**: Tasks affecting the same files must run sequentially
   - **Validation checkpoints**: Verify each phase completion before proceeding

8. Implementation execution rules:
   - **Setup first**: Initialize project structure, dependencies, configuration
   - **Tests before code**: If you need to write tests for contracts, entities, and integration scenarios
   - **Core development**: Implement models, services, CLI commands, endpoints
   - **Integration work**: Database connections, middleware, logging, external services
   - **Polish and validation**: Unit tests, performance optimization, documentation

9. **CRITICAL - No Stub/Placeholder Implementations**:
   - **NEVER** write stub code with comments like "In production, you would...", "Example: If we had...", "TODO: implement later"
   - **NEVER** leave commented-out example code showing what "should" be done
   - **NEVER** return empty/default data structures with explanatory comments
   - **If requirements are unclear** to fully implement a feature:
     1. **STOP** implementation of that specific task
     2. **ASK** the user specific clarifying questions (e.g., "Where should I get the list of instrument IDs from?", "What API should I call to fetch X?")
     3. **WAIT** for the user's answer before proceeding
     4. **IMPLEMENT** fully once requirements are clear
   - Every line of code must be production-ready - no placeholders, no "will be implemented later" patterns
   - If a dependency/data source is genuinely unknown, ask - don't guess or stub

10. Progress tracking and error handling:
   - Report progress after each completed task
   - Halt execution if any non-parallel task fails
   - For parallel tasks [P], continue with successful tasks, report failed ones
   - Provide clear error messages with context for debugging
   - Suggest next steps if implementation cannot proceed
   - **IMPORTANT** For completed tasks, make sure to mark the task off as [X] in the tasks file.

11. Completion validation:
   - Verify all required tasks are completed
   - Check that implemented features match the original specification
   - Validate that tests pass and coverage meets requirements
   - Confirm the implementation follows the technical plan
   - Report final status with summary of completed work

Note: This command assumes a complete task breakdown exists in tasks.md. If tasks are incomplete or missing, suggest running `/speckit.tasks` first to regenerate the task list.
