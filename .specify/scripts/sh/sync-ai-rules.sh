#!/bin/bash
# =============================================================================
# sync-ai-rules.sh — Multi-IDE Rules Generator
#
# Reads from .cursor/ (canonical source) and generates equivalent
# rules, skills, agents, and context files for:
#   - Claude Code  (.claude/, CLAUDE.md)
#   - Codex        (AGENTS.md)
#   - Copilot      (.github/instructions/, .github/agents/, .github/skills/)
#
# Usage:
#   ./sync-ai-rules.sh                  # Generate all enabled targets
#   ./sync-ai-rules.sh claude-code      # Generate only Claude Code
#   ./sync-ai-rules.sh codex            # Generate only Codex
#   ./sync-ai-rules.sh copilot          # Generate only Copilot
#   ./sync-ai-rules.sh --dry-run        # Show what would be generated
#   ./sync-ai-rules.sh --clean          # Remove all generated files
# =============================================================================

set -euo pipefail

capitalize() {
    local word="$1"
    local first
    first=$(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')
    echo "${first}${word:1}"
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.ai-rules.json"
CANONICAL_DIR="$REPO_ROOT/.cursor"

DRY_RUN=false
CLEAN=false
TARGET=""

GENERATED_COUNT=0

# =============================================================================
# Argument Parsing
# =============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        claude-code|codex|copilot)
            TARGET="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [target] [options]"
            echo ""
            echo "Targets:"
            echo "  claude-code    Generate .claude/ and CLAUDE.md"
            echo "  codex          Generate AGENTS.md"
            echo "  copilot        Generate .github/instructions/, agents/, skills/"
            echo "  (none)         Generate all enabled targets"
            echo ""
            echo "Options:"
            echo "  --dry-run      Show what would be generated without writing files"
            echo "  --clean        Remove all generated files"
            echo "  -h, --help     Show this help"
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'"
            echo "Run with --help for usage"
            exit 1
            ;;
    esac
done

# =============================================================================
# Configuration Parsing (reads .ai-rules.json via awk/sed — no jq dependency)
# =============================================================================

json_value() {
    local key="$1"
    local file="$2"
    awk -F'"' -v key="$key" '
        $2 == key { gsub(/^[[:space:]]*:[[:space:]]*"?|"?[[:space:]]*,?[[:space:]]*$/, "", $4); print $4; exit }
    ' "$file"
}

json_bool() {
    local key="$1"
    local file="$2"
    local val
    val=$(awk -v key="\"$key\"" '
        $0 ~ key { gsub(/.*:/, ""); gsub(/[[:space:],]/, ""); print; exit }
    ' "$file")
    [[ "$val" == "true" ]]
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Configuration file not found: $CONFIG_FILE"
        echo "Create .ai-rules.json in your repository root."
        exit 1
    fi

    PROJECT_NAME=$(json_value "name" "$CONFIG_FILE")
    PROJECT_DESC=$(json_value "description" "$CONFIG_FILE")
    PROJECT_TECH=$(json_value "techStack" "$CONFIG_FILE")

    CLAUDE_ENABLED=false
    CODEX_ENABLED=false
    COPILOT_ENABLED=false

    if json_bool "enabled" <(awk '/claude-code/,/\}/' "$CONFIG_FILE"); then
        CLAUDE_ENABLED=true
    fi
    if json_bool "enabled" <(awk '/codex/,/\}/' "$CONFIG_FILE"); then
        CODEX_ENABLED=true
    fi
    if json_bool "enabled" <(awk '/copilot/,/\}/' "$CONFIG_FILE"); then
        COPILOT_ENABLED=true
    fi
}

# =============================================================================
# Frontmatter Parsing Helpers
# =============================================================================

strip_frontmatter() {
    local file="$1"
    awk '
        BEGIN { in_fm=0; fm_done=0; has_fm=0 }
        /^---[[:space:]]*$/ {
            if (!fm_done) {
                if (in_fm) { fm_done=1; next }
                else { in_fm=1; has_fm=1; next }
            }
        }
        !has_fm { print; next }
        fm_done { print }
    ' "$file" | sed '/./,$!d'
}

get_frontmatter_field() {
    local file="$1"
    local field="$2"
    awk -v field="$field" '
        BEGIN { in_fm=0 }
        /^---[[:space:]]*$/ { if (in_fm) exit; in_fm=1; next }
        in_fm && $0 ~ "^"field":" {
            sub(/^[^:]*:[[:space:]]*/, "")
            gsub(/^"|"$/, "")
            print
            exit
        }
    ' "$file"
}

# =============================================================================
# File Generation Helpers
# =============================================================================

GENERATED_HEADER_COMMENT="<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->"

generated_header() {
    local source_path="$1"
    local regen_cmd="${2:-.specify/scripts/sh/sync-ai-rules.sh}"
    printf '%s\n' "$GENERATED_HEADER_COMMENT" "<!-- Source: $source_path | Regenerate: $regen_cmd -->" ""
}

write_file() {
    local target_path="$1"
    local content="$2"

    if $DRY_RUN; then
        echo "  [dry-run] Would write: $target_path"
        return
    fi

    mkdir -p "$(dirname "$target_path")"
    printf '%s\n' "$content" > "$target_path"
    GENERATED_COUNT=$((GENERATED_COUNT + 1))
}

copy_with_header() {
    local source="$1"
    local target="$2"
    local relative_source="${source#$REPO_ROOT/}"

    if $DRY_RUN; then
        echo "  [dry-run] Would copy: $relative_source -> $target"
        return
    fi

    mkdir -p "$(dirname "$target")"
    {
        generated_header "$relative_source"
        cat "$source"
    } > "$target"
    GENERATED_COUNT=$((GENERATED_COUNT + 1))
}

rewrite_paths() {
    local content="$1"
    local source_prefix="$2"
    local target_prefix="$3"
    echo "$content" | sed "s|$source_prefix|$target_prefix|g"
}

yaml_quote() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '"%s"' "$value"
}

# =============================================================================
# Clean Generated Files
# =============================================================================

clean_generated() {
    echo "Cleaning generated files..."

    local dirs_to_clean=(
        "$REPO_ROOT/.claude"
        "$REPO_ROOT/.codex"
        "$REPO_ROOT/.github/instructions"
        "$REPO_ROOT/.github/agents"
        "$REPO_ROOT/.github/skills"
    )
    local files_to_clean=(
        "$REPO_ROOT/CLAUDE.md"
        "$REPO_ROOT/AGENTS.md"
    )

    for dir in "${dirs_to_clean[@]}"; do
        if [[ -d "$dir" ]]; then
            if $DRY_RUN; then
                echo "  [dry-run] Would remove directory: ${dir#$REPO_ROOT/}"
            else
                rm -rf "$dir"
                echo "  Removed: ${dir#$REPO_ROOT/}"
            fi
        fi
    done

    for file in "${files_to_clean[@]}"; do
        if [[ -f "$file" ]]; then
            if $DRY_RUN; then
                echo "  [dry-run] Would remove: ${file#$REPO_ROOT/}"
            else
                rm -f "$file"
                echo "  Removed: ${file#$REPO_ROOT/}"
            fi
        fi
    done

    # Clean empty .github if we created it
    if [[ -d "$REPO_ROOT/.github" ]] && [[ -z "$(ls -A "$REPO_ROOT/.github" 2>/dev/null)" ]]; then
        if ! $DRY_RUN; then
            rmdir "$REPO_ROOT/.github" 2>/dev/null || true
        fi
    fi

    echo "Clean complete."
}

# =============================================================================
# Claude Code Generator
# =============================================================================

generate_claude_rules() {
    echo "  Generating .claude/rules/..."
    local target_dir="$REPO_ROOT/.claude/rules"

    for rule_file in "$CANONICAL_DIR"/rules/*.mdc; do
        [[ -f "$rule_file" ]] || continue
        local basename
        basename=$(basename "$rule_file" .mdc)
        local relative_source=".cursor/rules/$(basename "$rule_file")"

        local description
        description=$(get_frontmatter_field "$rule_file" "description")

        local body
        body=$(strip_frontmatter "$rule_file")
        body=$(rewrite_paths "$body" ".cursor/agents/" ".claude/agents/")
        body=$(rewrite_paths "$body" ".cursor/skills/" ".claude/skills/")

        local content
        content=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh claude-code")$'\n'
        if [[ -n "$description" ]]; then
            content+="<!-- Description: $description -->"$'\n'
            content+=""$'\n'
        fi
        content+="$body"

        write_file "$target_dir/$basename.md" "$content"
    done
}

generate_claude_skills() {
    echo "  Generating .claude/skills/..."

    for tier in core team; do
        local source_dir="$CANONICAL_DIR/skills/$tier"
        [[ -d "$source_dir" ]] || continue

        for skill_dir in "$source_dir"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name
            skill_name=$(basename "$skill_dir")
            local source_file="$skill_dir/SKILL.md"
            [[ -f "$source_file" ]] || continue

            local target_file="$REPO_ROOT/.claude/skills/$tier/$skill_name/SKILL.md"
            local relative_source=".cursor/skills/$tier/$skill_name/SKILL.md"

            local body
            body=$(cat "$source_file")
            body=$(rewrite_paths "$body" ".cursor/skills/" ".claude/skills/")
            body=$(rewrite_paths "$body" ".cursor/agents/" ".claude/agents/")

            local content
            content=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh claude-code")$'\n'
            content+="$body"

            write_file "$target_file" "$content"
        done
    done
}

generate_claude_agents() {
    echo "  Generating .claude/agents/..."

    for tier in core team; do
        local source_dir="$CANONICAL_DIR/agents/$tier"
        [[ -d "$source_dir" ]] || continue

        for agent_file in "$source_dir"/*.md; do
            [[ -f "$agent_file" ]] || continue
            local basename
            basename=$(basename "$agent_file")
            local relative_source=".cursor/agents/$tier/$basename"

            local name
            name=$(get_frontmatter_field "$agent_file" "name")
            local description
            description=$(get_frontmatter_field "$agent_file" "description")

            local body
            body=$(strip_frontmatter "$agent_file")
            body=$(rewrite_paths "$body" ".cursor/skills/" ".claude/skills/")
            body=$(rewrite_paths "$body" ".cursor/agents/" ".claude/agents/")

            local content
            content=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh claude-code")$'\n'
            if [[ -n "$name" ]] || [[ -n "$description" ]]; then
                content+="---"$'\n'
                [[ -n "$name" ]] && content+="name: $name"$'\n'
                [[ -n "$description" ]] && content+="description: $description"$'\n'
                content+="---"$'\n'
                content+=""$'\n'
            fi
            content+="$body"

            write_file "$REPO_ROOT/.claude/agents/$tier/$basename" "$content"
        done
    done
}

generate_claude_commands() {
    echo "  Generating .claude/commands/..."
    local source_dir="$CANONICAL_DIR/commands"
    local target_dir="$REPO_ROOT/.claude/commands"

    [[ -d "$source_dir" ]] || return 0

    for cmd_file in "$source_dir"/*.md; do
        [[ -f "$cmd_file" ]] || continue
        local basename
        basename=$(basename "$cmd_file")
        local relative_source=".cursor/commands/$basename"

        local description
        description=$(get_frontmatter_field "$cmd_file" "description")

        local body
        body=$(strip_frontmatter "$cmd_file")
        body=$(rewrite_paths "$body" ".cursor/skills/" ".claude/skills/")
        body=$(rewrite_paths "$body" ".cursor/agents/" ".claude/agents/")

        local content
        content=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh claude-code")$'\n'
        if [[ -n "$description" ]]; then
            content+="<!-- Description: $description -->"$'\n'
            content+=""$'\n'
        fi
        content+="$body"

        write_file "$target_dir/$basename" "$content"
    done
}

generate_claude_md() {
    echo "  Generating CLAUDE.md..."

    local content=""
    content+="$GENERATED_HEADER_COMMENT"$'\n'
    content+="<!-- Regenerate: .specify/scripts/sh/sync-ai-rules.sh claude-code -->"$'\n'
    content+=""$'\n'
    content+="# $PROJECT_NAME"$'\n'
    content+=""$'\n'
    content+="$PROJECT_DESC"$'\n'
    content+=""$'\n'
    content+="## Tech Stack"$'\n'
    content+=""$'\n'
    content+="$PROJECT_TECH"$'\n'
    content+=""$'\n'

    # Architecture Agents section
    content+="## Architecture Agents"$'\n'
    content+=""$'\n'
    content+="Read the appropriate agent pair (core + team) based on the layer you are working in:"$'\n'
    content+=""$'\n'

    for agent_file in "$CANONICAL_DIR"/agents/core/*.md; do
        [[ -f "$agent_file" ]] || continue
        local name
        name=$(basename "$agent_file")
        local agent_name
        agent_name=$(get_frontmatter_field "$agent_file" "name")
        local description
        description=$(get_frontmatter_field "$agent_file" "description")

        content+="### $agent_name"$'\n'
        if [[ -n "$description" ]]; then
            content+="$description"$'\n'
        fi
        content+="- Core: \`.claude/agents/core/$name\`"$'\n'
        if [[ -f "$CANONICAL_DIR/agents/team/$name" ]]; then
            content+="- Team: \`.claude/agents/team/$name\`"$'\n'
        fi
        content+=""$'\n'
    done

    # Skills Reference section
    content+="## Skills Reference"$'\n'
    content+=""$'\n'

    for tier in core team; do
        local source_dir="$CANONICAL_DIR/skills/$tier"
        [[ -d "$source_dir" ]] || continue

        content+="### $(capitalize "$tier") Skills"$'\n'
        content+=""$'\n'

        for skill_dir in "$source_dir"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name
            skill_name=$(basename "$skill_dir")
            local skill_file="$skill_dir/SKILL.md"
            [[ -f "$skill_file" ]] || continue

            local when_to_use=""
            when_to_use=$(awk '/^## When to Use/,/^##[^#]/ { if (/^## When to Use/) next; if (/^##[^#]/) exit; print }' "$skill_file" | head -3 | tr '\n' ' ' | sed 's/[[:space:]]*$//')

            content+="- **$skill_name** (\`.claude/skills/$tier/$skill_name/SKILL.md\`)"
            if [[ -n "$when_to_use" ]]; then
                content+=" — $when_to_use"
            fi
            content+=$'\n'
        done
        content+=""$'\n'
    done

    # Key Conventions from rules
    content+="## Key Conventions"$'\n'
    content+=""$'\n'

    for rule_file in "$CANONICAL_DIR"/rules/*.mdc; do
        [[ -f "$rule_file" ]] || continue
        local basename
        basename=$(basename "$rule_file" .mdc)
        local description
        description=$(get_frontmatter_field "$rule_file" "description")
        local body
        body=$(strip_frontmatter "$rule_file")
        body=$(rewrite_paths "$body" ".cursor/agents/" ".claude/agents/")
        body=$(rewrite_paths "$body" ".cursor/skills/" ".claude/skills/")

        content+="### $basename"$'\n'
        if [[ -n "$description" ]]; then
            content+="$description"$'\n'
        fi
        content+=""$'\n'
        content+="$body"$'\n'
        content+=""$'\n'
    done

    write_file "$REPO_ROOT/CLAUDE.md" "$content"
}

generate_claude_code() {
    echo ""
    echo "=== Claude Code ==="
    generate_claude_rules
    generate_claude_skills
    generate_claude_agents
    generate_claude_commands
    generate_claude_md
}

# =============================================================================
# Codex Generator
#
# Codex conventions (learned from ~/.codex/):
#   - Skills: flat dirs under .codex/skills/{name}/ with SKILL.md + agents/openai.yaml
#   - Agents: flat .md files under .codex/agents/ (frontmatter: name, description, model)
#   - Rules:  .mdc files under .codex/rules/ (same format as Cursor)
#   - Commands: .md files under .codex/commands/ (frontmatter: description, handoffs)
#   - AGENTS.md: aggregated project context at repo root
# =============================================================================

codex_flat_skill_name() {
    local tier="$1"
    local skill_name="$2"
    echo "${tier}-${skill_name}"
}

generate_codex_rules() {
    echo "  Generating .codex/rules/..."
    local target_dir="$REPO_ROOT/.codex/rules"

    for rule_file in "$CANONICAL_DIR"/rules/*.mdc; do
        [[ -f "$rule_file" ]] || continue
        local basename
        basename=$(basename "$rule_file")
        local relative_source=".cursor/rules/$basename"

        local body
        body=$(cat "$rule_file")
        # Rewrite skill paths: .cursor/skills/{tier}/{name}/ -> .codex/skills/{tier}-{name}/
        body=$(echo "$body" | sed -E 's#\.cursor/skills/(core|team)/([^/]+)/#.codex/skills/\1-\2/#g')
        body=$(echo "$body" | sed 's|\.cursor/agents/core/|.codex/agents/core-|g; s|\.cursor/agents/team/|.codex/agents/team-|g')
        # Fix .md extension: .codex/agents/core-name.md (not core-name.md.md)
        body=$(echo "$body" | sed -E 's|(\.codex/agents/[a-z]+-[a-z-]+)\.md|\1|g')

        local content
        content=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh codex")$'\n'
        content+="$body"

        write_file "$target_dir/$basename" "$content"
    done
}

generate_codex_skills() {
    echo "  Generating .codex/skills/..."

    for tier in core team; do
        local source_dir="$CANONICAL_DIR/skills/$tier"
        [[ -d "$source_dir" ]] || continue

        for skill_dir in "$source_dir"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name
            skill_name=$(basename "$skill_dir")
            local flat_name
            flat_name=$(codex_flat_skill_name "$tier" "$skill_name")
            local source_file="$skill_dir/SKILL.md"
            [[ -f "$source_file" ]] || continue

            local relative_source=".cursor/skills/$tier/$skill_name/SKILL.md"

            # Read existing frontmatter fields
            local orig_name
            orig_name=$(get_frontmatter_field "$source_file" "name")
            local orig_desc
            orig_desc=$(get_frontmatter_field "$source_file" "description")

            # Extract first H1 heading for display_name
            local display_name
            display_name=$(awk '/^# / { sub(/^# /, ""); print; exit }' "$source_file")
            [[ -z "$display_name" ]] && display_name="$flat_name"

            # Extract "When to Use" for short_description
            local short_desc
            short_desc=$(awk '
                /^## When to Use/ { capture=1; next }
                /^## / { if (capture) exit }
                capture {
                    gsub(/^[[:space:]]+/, "")
                    if (length($0) > 0) { print; exit }
                }
            ' "$source_file")
            [[ -z "$short_desc" ]] && short_desc="${orig_desc:-$flat_name skill}"

            # Build SKILL.md with proper Codex frontmatter
            local body
            body=$(strip_frontmatter "$source_file")
            # Rewrite skill paths to flat Codex structure
            body=$(echo "$body" | sed -E 's#\.cursor/skills/(core|team)/([^/]+)/#.codex/skills/\1-\2/#g')
            body=$(echo "$body" | sed 's|\.cursor/agents/core/|.codex/agents/core-|g; s|\.cursor/agents/team/|.codex/agents/team-|g')

            local skill_content
            local skill_desc
            skill_desc="${orig_desc:-$short_desc}"
            [[ -z "$skill_desc" ]] && skill_desc="$flat_name skill"

            skill_content=""
            skill_content+="---"$'\n'
            skill_content+="name: $(yaml_quote "$flat_name")"$'\n'
            skill_content+="description: $(yaml_quote "$skill_desc")"$'\n'
            skill_content+="metadata:"$'\n'
            skill_content+="  short-description: $(yaml_quote "$short_desc")"$'\n'
            skill_content+="---"$'\n'
            skill_content+=""$'\n'
            skill_content+=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh codex")$'\n'
            skill_content+="$body"

            write_file "$REPO_ROOT/.codex/skills/$flat_name/SKILL.md" "$skill_content"

            # Generate agents/openai.yaml (Codex skill UI metadata)
            # Truncate short_desc to 64 chars for Codex UI constraint
            local truncated_desc="${short_desc:0:64}"
            local yaml_content="interface:"$'\n'
            yaml_content+="  display_name: \"$display_name\""$'\n'
            yaml_content+="  short_description: \"$truncated_desc\""

            write_file "$REPO_ROOT/.codex/skills/$flat_name/agents/openai.yaml" "$yaml_content"
        done
    done
}

generate_codex_agents() {
    echo "  Generating .codex/agents/..."

    # Codex agents are flat (no core/team subdirs)
    # We prefix with tier to avoid name collisions
    for tier in core team; do
        local source_dir="$CANONICAL_DIR/agents/$tier"
        [[ -d "$source_dir" ]] || continue

        for agent_file in "$source_dir"/*.md; do
            [[ -f "$agent_file" ]] || continue
            local basename
            basename=$(basename "$agent_file" .md)
            local relative_source=".cursor/agents/$tier/$(basename "$agent_file")"

            local name
            name=$(get_frontmatter_field "$agent_file" "name")
            local description
            description=$(get_frontmatter_field "$agent_file" "description")

            local body
            body=$(strip_frontmatter "$agent_file")
            # Rewrite skill paths to flat Codex structure
            body=$(echo "$body" | sed -E 's#\.cursor/skills/(core|team)/([^/]+)/#.codex/skills/\1-\2/#g')
            body=$(echo "$body" | sed 's|\.cursor/agents/core/|.codex/agents/core-|g; s|\.cursor/agents/team/|.codex/agents/team-|g')

            local content
            [[ -z "$name" ]] && name="$tier-$basename"
            [[ -z "$description" ]] && description="$name agent instructions"

            content=""
            content+="---"$'\n'
            content+="name: $(yaml_quote "$name")"$'\n'
            content+="description: $(yaml_quote "$description")"$'\n'
            content+="---"$'\n'
            content+=""$'\n'
            content+=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh codex")$'\n'
            content+="$body"

            # Team agents keep same name (override core) — this matches
            # how Codex uses flat agents with the team version taking precedence
            write_file "$REPO_ROOT/.codex/agents/$tier-$basename.md" "$content"
        done
    done
}

generate_codex_commands() {
    echo "  Generating .codex/commands/..."
    local source_dir="$CANONICAL_DIR/commands"
    local target_dir="$REPO_ROOT/.codex/commands"

    [[ -d "$source_dir" ]] || return 0

    for cmd_file in "$source_dir"/*.md; do
        [[ -f "$cmd_file" ]] || continue
        local basename
        basename=$(basename "$cmd_file")
        local relative_source=".cursor/commands/$basename"

        local description
        description=$(get_frontmatter_field "$cmd_file" "description")

        local body
        body=$(strip_frontmatter "$cmd_file")
        body=$(rewrite_paths "$body" ".cursor/skills/" ".codex/skills/")
        body=$(rewrite_paths "$body" ".cursor/agents/" ".codex/agents/")

        local content
        content=""
        if [[ -n "$description" ]]; then
            content+="---"$'\n'
            content+="description: $(yaml_quote "$description")"$'\n'
            content+="---"$'\n'
            content+=""$'\n'
        fi
        content+=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh codex")$'\n'
        content+="$body"

        write_file "$target_dir/$basename" "$content"
    done
}

generate_agents_md() {
    echo "  Generating AGENTS.md..."

    local content=""
    content+="$GENERATED_HEADER_COMMENT"$'\n'
    content+="<!-- Regenerate: .specify/scripts/sh/sync-ai-rules.sh codex -->"$'\n'
    content+=""$'\n'
    content+="# $PROJECT_NAME"$'\n'
    content+=""$'\n'
    content+="$PROJECT_DESC"$'\n'
    content+=""$'\n'
    content+="**Tech Stack:** $PROJECT_TECH"$'\n'
    content+=""$'\n'

    # Agents section
    content+="## Architecture Agents"$'\n'
    content+=""$'\n'
    content+="Read the appropriate agent based on the layer you are working in. Each role has a core (architecture) and team (library-specific) variant in \`.codex/agents/\`."$'\n'
    content+=""$'\n'

    for agent_file in "$CANONICAL_DIR"/agents/core/*.md; do
        [[ -f "$agent_file" ]] || continue
        local basename
        basename=$(basename "$agent_file" .md)
        local agent_name
        agent_name=$(get_frontmatter_field "$agent_file" "name")
        local description
        description=$(get_frontmatter_field "$agent_file" "description")

        content+="### $agent_name"$'\n'
        if [[ -n "$description" ]]; then
            content+="$description"$'\n'
        fi
        content+="- Core: \`.codex/agents/core-$basename.md\`"$'\n'
        if [[ -f "$CANONICAL_DIR/agents/team/$basename.md" ]]; then
            content+="- Team: \`.codex/agents/team-$basename.md\`"$'\n'
        fi
        content+=""$'\n'
    done

    # Skills Reference section
    content+="## Skills Reference"$'\n'
    content+=""$'\n'
    content+="Skills are in \`.codex/skills/\`. Invoke with \`\$skill-name\` in Codex."$'\n'
    content+=""$'\n'

    for tier in core team; do
        local source_dir="$CANONICAL_DIR/skills/$tier"
        [[ -d "$source_dir" ]] || continue

        content+="### $(capitalize "$tier") Skills"$'\n'
        content+=""$'\n'

        for skill_dir in "$source_dir"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name
            skill_name=$(basename "$skill_dir")
            local flat_name
            flat_name=$(codex_flat_skill_name "$tier" "$skill_name")
            local skill_file="$skill_dir/SKILL.md"
            [[ -f "$skill_file" ]] || continue

            local when_to_use=""
            when_to_use=$(awk '/^## When to Use/,/^##[^#]/ { if (/^## When to Use/) next; if (/^##[^#]/) exit; print }' "$skill_file" | head -3 | tr '\n' ' ' | sed 's/[[:space:]]*$//')

            content+="- **\`\$$flat_name\`** (\`.codex/skills/$flat_name/SKILL.md\`)"
            if [[ -n "$when_to_use" ]]; then
                content+=" — $when_to_use"
            fi
            content+=$'\n'
        done
        content+=""$'\n'
    done

    # Key Conventions from rules
    content+="## Key Conventions"$'\n'
    content+=""$'\n'

    for rule_file in "$CANONICAL_DIR"/rules/*.mdc; do
        [[ -f "$rule_file" ]] || continue
        local basename
        basename=$(basename "$rule_file" .mdc)
        local description
        description=$(get_frontmatter_field "$rule_file" "description")
        local body
        body=$(strip_frontmatter "$rule_file")
        body=$(echo "$body" | sed -E 's#\.cursor/skills/(core|team)/([^/]+)/#.codex/skills/\1-\2/#g')
        body=$(echo "$body" | sed 's|\.cursor/agents/core/|.codex/agents/core-|g; s|\.cursor/agents/team/|.codex/agents/team-|g')

        content+="### $basename"$'\n'
        if [[ -n "$description" ]]; then
            content+="$description"$'\n'
        fi
        content+=""$'\n'
        content+="$body"$'\n'
        content+=""$'\n'
    done

    write_file "$REPO_ROOT/AGENTS.md" "$content"
}

generate_codex() {
    echo ""
    echo "=== Codex ==="
    generate_codex_rules
    generate_codex_skills
    generate_codex_agents
    generate_codex_commands
    generate_agents_md
}

# =============================================================================
# GitHub Copilot Generator
# =============================================================================

generate_copilot_instructions() {
    echo "  Generating .github/instructions/..."
    local target_dir="$REPO_ROOT/.github/instructions"

    for rule_file in "$CANONICAL_DIR"/rules/*.mdc; do
        [[ -f "$rule_file" ]] || continue
        local basename
        basename=$(basename "$rule_file" .mdc)
        local relative_source=".cursor/rules/$(basename "$rule_file")"

        local description
        description=$(get_frontmatter_field "$rule_file" "description")
        local globs
        globs=$(get_frontmatter_field "$rule_file" "globs")

        local body
        body=$(strip_frontmatter "$rule_file")
        body=$(rewrite_paths "$body" ".cursor/agents/" ".github/agents/")
        body=$(rewrite_paths "$body" ".cursor/skills/" ".github/skills/")

        # Convert JSON array globs to comma-separated pattern for Copilot
        local apply_to
        apply_to=$(echo "$globs" | sed 's/\[//;s/\]//;s/"//g;s/,[[:space:]]*/,/g' | tr -d ' ')

        local content
        content=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh copilot")$'\n'
        content+="---"$'\n'
        content+="applyTo: \"$apply_to\""$'\n'
        content+="---"$'\n'
        content+=""$'\n'
        if [[ -n "$description" ]]; then
            content+="# $basename"$'\n'
            content+="$description"$'\n'
            content+=""$'\n'
        fi
        content+="$body"

        write_file "$target_dir/$basename.instructions.md" "$content"
    done
}

generate_copilot_agents() {
    echo "  Generating .github/agents/..."
    local target_dir="$REPO_ROOT/.github/agents"

    for tier in core team; do
        local source_dir="$CANONICAL_DIR/agents/$tier"
        [[ -d "$source_dir" ]] || continue

        for agent_file in "$source_dir"/*.md; do
            [[ -f "$agent_file" ]] || continue
            local basename
            basename=$(basename "$agent_file" .md)
            local relative_source=".cursor/agents/$tier/$(basename "$agent_file")"

            local name
            name=$(get_frontmatter_field "$agent_file" "name")
            local description
            description=$(get_frontmatter_field "$agent_file" "description")

            local body
            body=$(strip_frontmatter "$agent_file")
            body=$(rewrite_paths "$body" ".cursor/skills/" ".github/skills/")
            body=$(rewrite_paths "$body" ".cursor/agents/" ".github/agents/")

            local content
            content=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh copilot")$'\n'
            content+="---"$'\n'
            content+="description: \"$description\""$'\n'
            content+="---"$'\n'
            content+=""$'\n'
            content+="$body"

            write_file "$target_dir/$tier-$basename.agent.md" "$content"
        done
    done
}

generate_copilot_skills() {
    echo "  Generating .github/skills/..."

    for tier in core team; do
        local source_dir="$CANONICAL_DIR/skills/$tier"
        [[ -d "$source_dir" ]] || continue

        for skill_dir in "$source_dir"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name
            skill_name=$(basename "$skill_dir")
            local source_file="$skill_dir/SKILL.md"
            [[ -f "$source_file" ]] || continue

            local target_file="$REPO_ROOT/.github/skills/$tier/$skill_name/SKILL.md"
            local relative_source=".cursor/skills/$tier/$skill_name/SKILL.md"

            local body
            body=$(cat "$source_file")
            body=$(rewrite_paths "$body" ".cursor/skills/" ".github/skills/")
            body=$(rewrite_paths "$body" ".cursor/agents/" ".github/agents/")

            local content
            content=$(generated_header "$relative_source" ".specify/scripts/sh/sync-ai-rules.sh copilot")$'\n'
            content+="$body"

            write_file "$target_file" "$content"
        done
    done
}

generate_copilot() {
    echo ""
    echo "=== GitHub Copilot ==="
    generate_copilot_instructions
    generate_copilot_agents
    generate_copilot_skills
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo "sync-ai-rules: Multi-IDE Rules Generator"
    echo "========================================="

    if $CLEAN; then
        clean_generated
        exit 0
    fi

    if [[ ! -d "$CANONICAL_DIR" ]]; then
        echo "Error: Canonical source not found: $CANONICAL_DIR"
        exit 1
    fi

    load_config

    echo "Project: $PROJECT_NAME"
    echo "Canonical: .cursor/"
    if $DRY_RUN; then
        echo "Mode: DRY RUN (no files will be written)"
    fi

    local ran_any=false

    if [[ -z "$TARGET" || "$TARGET" == "claude-code" ]]; then
        if $CLAUDE_ENABLED || [[ "$TARGET" == "claude-code" ]]; then
            generate_claude_code
            ran_any=true
        fi
    fi

    if [[ -z "$TARGET" || "$TARGET" == "codex" ]]; then
        if $CODEX_ENABLED || [[ "$TARGET" == "codex" ]]; then
            generate_codex
            ran_any=true
        fi
    fi

    if [[ -z "$TARGET" || "$TARGET" == "copilot" ]]; then
        if $COPILOT_ENABLED || [[ "$TARGET" == "copilot" ]]; then
            generate_copilot
            ran_any=true
        fi
    fi

    if ! $ran_any; then
        echo ""
        echo "No targets enabled. Check .ai-rules.json targets configuration."
        exit 1
    fi

    echo ""
    echo "========================================="
    if $DRY_RUN; then
        echo "Dry run complete. No files were written."
    else
        echo "Generation complete. $GENERATED_COUNT files written."
    fi
}

main
