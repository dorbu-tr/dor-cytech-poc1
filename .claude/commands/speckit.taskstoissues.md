<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->
<!-- Source: .cursor/commands/speckit.taskstoissues.md | Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->
<!-- Description: Convert existing tasks into actionable, dependency-ordered GitHub issues for the feature based on available design artifacts. -->

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. Run the check-prerequisites script from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").
   - **Unix/macOS**: `.specify/scripts/sh/check-prerequisites.sh --json --require-tasks --include-tasks`
   - **Windows (PowerShell)**: `.specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks`
1. From the executed script, extract the path to **tasks**.
1. Get the Git remote by running:

```bash
git config --get remote.origin.url
```

> [!CAUTION]
> ONLY PROCEED TO NEXT STEPS IF THE REMOTE IS A GITHUB URL

1. For each task in the list, use the GitHub MCP server to create a new issue in the repository that is representative of the Git remote.

> [!CAUTION]
> UNDER NO CIRCUMSTANCES EVER CREATE ISSUES IN REPOSITORIES THAT DO NOT MATCH THE REMOTE URL
