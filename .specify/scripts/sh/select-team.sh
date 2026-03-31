#!/bin/bash
# =============================================================================
# select-team.sh — Team Materialization Script
#
# Transforms the unified multi-team template into a single-team template by:
#   1. Copying team-specific AI content (skills, agents, constitution, reference)
#   2. Overlaying team-specific source files (KEEP files)
#   2.5. Removing team-excluded files (from "remove" in team.json)
#   3. Replacing NuGet packages in .csproj files
#   4. Removing all other teams and the teams/ infrastructure
#   5. Running sync-ai-rules.sh to generate multi-IDE outputs
#
# This is a ONE-TIME, DESTRUCTIVE operation. After running, the repo
# contains only the selected team's content.
#
# Usage:
#   ./select-team.sh <team-id>         # Materialize for a team
#   ./select-team.sh --list            # List available teams
#   ./select-team.sh --dry-run <team>  # Preview without writing
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEAMS_DIR="$REPO_ROOT/teams"
TEAMS_JSON="$REPO_ROOT/teams.json"

DRY_RUN=false
TEAM_ID=""

PREFIX="dor-cytech-poc1"

# =============================================================================
# Argument Parsing
# =============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)
            if [[ ! -f "$TEAMS_JSON" ]]; then
                echo "Error: teams.json not found. Has select-team already been run?"
                exit 1
            fi
            echo "Available teams:"
            echo ""
            awk -F'"' '/"id"/ { id=$4 } /"name"/ { name=$4 } /"description"/ { desc=$4; printf "  %-15s %s — %s\n", id, name, desc }' "$TEAMS_JSON"
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [options] <team-id>"
            echo ""
            echo "Materializes the unified template for a specific team."
            echo "This is a ONE-TIME, DESTRUCTIVE operation."
            echo ""
            echo "Commands:"
            echo "  <team-id>       Materialize the template for the given team"
            echo "  --list          List available teams"
            echo "  --dry-run       Preview changes without writing"
            echo "  -h, --help      Show this help"
            exit 0
            ;;
        -*)
            echo "Error: Unknown option '$1'"
            exit 1
            ;;
        *)
            TEAM_ID="$1"
            shift
            ;;
    esac
done

if [[ -z "$TEAM_ID" ]]; then
    echo "Error: No team specified."
    echo "Usage: $(basename "$0") <team-id>"
    echo "Run with --list to see available teams."
    exit 1
fi

# =============================================================================
# Validation
# =============================================================================

TEAM_DIR="$TEAMS_DIR/$TEAM_ID"

if [[ ! -d "$TEAM_DIR" ]]; then
    echo "Error: Team '$TEAM_ID' not found in $TEAMS_DIR/"
    echo "Available teams:"
    ls -1 "$TEAMS_DIR" 2>/dev/null || echo "  (none)"
    exit 1
fi

TEAM_JSON="$TEAM_DIR/team.json"
if [[ ! -f "$TEAM_JSON" ]]; then
    echo "Error: team.json not found for team '$TEAM_ID'"
    exit 1
fi

TEAM_NAME=$(awk -F'"' '/"name"/ { print $4; exit }' "$TEAM_JSON")

echo "============================================"
echo "select-team: Team Materialization"
echo "============================================"
echo "Team:     $TEAM_ID ($TEAM_NAME)"
echo "Repo:     $REPO_ROOT"
if $DRY_RUN; then
    echo "Mode:     DRY RUN (no changes will be made)"
fi
echo ""

# =============================================================================
# Helpers
# =============================================================================

action() {
    local msg="$1"
    if $DRY_RUN; then
        echo "  [dry-run] $msg"
    else
        echo "  $msg"
    fi
}

ACTIONS_COUNT=0

# =============================================================================
# Step 1: Copy AI content
# =============================================================================

echo "--- Step 1: Copy team AI content ---"

# Skills
if [[ -d "$TEAM_DIR/skills" ]]; then
    action "Copy skills -> .cursor/skills/team/"
    if ! $DRY_RUN; then
        mkdir -p "$REPO_ROOT/.cursor/skills/team"
        cp -R "$TEAM_DIR/skills/"* "$REPO_ROOT/.cursor/skills/team/"
    fi
    ACTIONS_COUNT=$((ACTIONS_COUNT + 1))
fi

# Agents
if [[ -d "$TEAM_DIR/agents" ]]; then
    action "Copy agents -> .cursor/agents/team/"
    if ! $DRY_RUN; then
        mkdir -p "$REPO_ROOT/.cursor/agents/team"
        cp -R "$TEAM_DIR/agents/"* "$REPO_ROOT/.cursor/agents/team/"
    fi
    ACTIONS_COUNT=$((ACTIONS_COUNT + 1))
fi

# Constitution
if [[ -f "$TEAM_DIR/constitution-team.md" ]]; then
    action "Copy constitution-team.md -> .specify/memory/"
    if ! $DRY_RUN; then
        cp "$TEAM_DIR/constitution-team.md" "$REPO_ROOT/.specify/memory/constitution-team.md"
    fi
    ACTIONS_COUNT=$((ACTIONS_COUNT + 1))
fi

# Reference implementations
if [[ -d "$TEAM_DIR/reference" ]]; then
    action "Copy reference/ -> .reference/"
    if ! $DRY_RUN; then
        mkdir -p "$REPO_ROOT/.reference"
        cp -R "$TEAM_DIR/reference/"* "$REPO_ROOT/.reference/"
    fi
    ACTIONS_COUNT=$((ACTIONS_COUNT + 1))
fi

echo ""

# =============================================================================
# Step 1.5: Clone example projects to .examples/
# =============================================================================

echo "--- Step 1.5: Clone team example projects ---"

EXAMPLES_DIR="$REPO_ROOT/.examples"

# Parse example URLs from team.json using awk
example_count=0
while IFS='|' read -r name url; do
    [[ -z "$name" || -z "$url" ]] && continue
    example_count=$((example_count + 1))
    example_dir="$EXAMPLES_DIR/$name"

    if $DRY_RUN; then
        action "Clone example: $name -> .examples/$name"
    else
        action "Clone example: $name -> .examples/$name"
        mkdir -p "$EXAMPLES_DIR"
        if command -v gh &>/dev/null; then
            gh repo clone "$url" "$example_dir" -- --depth 1 2>/dev/null || \
                git clone --depth 1 "$url" "$example_dir" 2>/dev/null || \
                echo "  Warning: Failed to clone $name ($url) — skipping"
        else
            git clone --depth 1 "$url" "$example_dir" 2>/dev/null || \
                echo "  Warning: Failed to clone $name ($url) — skipping"
        fi
        # Remove .git to save space
        rm -rf "$example_dir/.git" 2>/dev/null
    fi
    ACTIONS_COUNT=$((ACTIONS_COUNT + 1))
done < <(awk '
    BEGIN { in_examples=0; in_obj=0; name=""; url="" }
    /"examples"[[:space:]]*:/ { in_examples=1; next }
    in_examples && /\]/ { in_examples=0; next }
    in_examples && /\{/ { in_obj=1; name=""; url=""; next }
    in_examples && in_obj && /"name"/ {
        line=$0
        gsub(/.*"name"[[:space:]]*:[[:space:]]*"/, "", line)
        split(line, parts, "\"")
        name=parts[1]
    }
    in_examples && in_obj && /"url"/ {
        line=$0
        gsub(/.*"url"[[:space:]]*:[[:space:]]*"/, "", line)
        split(line, parts, "\"")
        url=parts[1]
    }
    in_examples && in_obj && /\}/ {
        if (name != "" && url != "") printf "%s|%s\n", name, url
        in_obj=0
    }
' "$TEAM_JSON")

if [[ $example_count -eq 0 ]]; then
    echo "  (no example projects defined for this team)"
fi

echo ""

# =============================================================================
# Step 2: Overlay source files (KEEP files)
# =============================================================================

echo "--- Step 2: Overlay team source files ---"

if [[ -d "$TEAM_DIR/src" ]]; then
    # Map layer names to actual project directories
    for layer_dir in "$TEAM_DIR/src"/*/; do
        [[ -d "$layer_dir" ]] || continue
        layer_name=$(basename "$layer_dir")

        # Map generic layer name to project directory
        if [[ "$layer_name" == Tests.* ]]; then
            project_dir="$REPO_ROOT/Tests/${PREFIX}.${layer_name}"
        else
            project_dir="$REPO_ROOT/src/${PREFIX}.${layer_name}"
        fi
        if [[ ! -d "$project_dir" ]]; then
            echo "  Warning: Project directory not found for layer '$layer_name': $project_dir"
            continue
        fi

        # Copy all files from the overlay, preserving directory structure
        while IFS= read -r -d '' src_file; do
            rel_path="${src_file#$layer_dir}"
            target_file="$project_dir/$rel_path"
            action "Overlay: ${PREFIX}.${layer_name}/$rel_path"
            if ! $DRY_RUN; then
                mkdir -p "$(dirname "$target_file")"
                cp "$src_file" "$target_file"
            fi
            ACTIONS_COUNT=$((ACTIONS_COUNT + 1))
        done < <(find "$layer_dir" -type f -print0)
    done
else
    echo "  (no source overlay for this team)"
fi

echo ""

# =============================================================================
# Step 2.5: Remove team-excluded files
# =============================================================================

echo "--- Step 2.5: Remove team-excluded files ---"

# Parse the "remove" section from team.json and delete matching files.
# Format: "remove": { "Layer": ["file1.cs", "file2.cs"], ... }

remove_count=0

while IFS='|' read -r layer file; do
    [[ -z "$layer" || -z "$file" ]] && continue
    if [[ "$layer" == Tests.* ]]; then
        target="$REPO_ROOT/Tests/${PREFIX}.${layer}/${file}"
    else
        target="$REPO_ROOT/src/${PREFIX}.${layer}/${file}"
    fi
    if [[ -f "$target" ]]; then
        action "Remove: ${PREFIX}.${layer}/${file}"
        if ! $DRY_RUN; then
            rm -f "$target"
        fi
        remove_count=$((remove_count + 1))
        ACTIONS_COUNT=$((ACTIONS_COUNT + 1))
    fi
done < <(awk '
    BEGIN { in_remove=0; in_layer=0; layer="" }
    /"remove"[[:space:]]*:/ { in_remove=1; next }
    in_remove && /\}[[:space:]]*,?[[:space:]]*$/ && !in_layer { in_remove=0; next }
    in_remove && !in_layer {
        line=$0
        if (line ~ /"[^"]+\"[[:space:]]*:/) {
            gsub(/.*"/, "", line)
            gsub(/".*/, "", line)
            # line now has the layer name (may be empty if parsing went wrong)
            # re-extract properly
            line=$0
            gsub(/^[^"]*"/, "", line)
            split(line, kparts, "\"")
            layer=kparts[1]
            if (layer != "") {
                in_layer=1
                if ($0 ~ /\[\]/) { in_layer=0; next }
                next
            }
        }
    }
    in_remove && in_layer && /\]/ { in_layer=0; next }
    in_remove && in_layer {
        line=$0
        gsub(/^[^"]*"/, "", line)
        split(line, fparts, "\"")
        fname=fparts[1]
        if (fname != "" && fname ~ /\./) {
            printf "%s|%s\n", layer, fname
        }
    }
' "$TEAM_JSON")

if [[ $remove_count -eq 0 ]]; then
    echo "  (no files to remove for this team)"
fi

echo ""

# =============================================================================
# Step 3: Patch NuGet packages in .csproj files
# =============================================================================

echo "--- Step 3: Patch NuGet packages ---"

# Parse team.json nugets section and replace PackageReference blocks in .csproj files.
# Uses awk to extract the package list per project layer from team.json,
# then replaces the first <ItemGroup> containing <PackageReference> in each .csproj.

patch_nugets_for_layer() {
    local layer="$1"
    local csproj_path=""

    # Find the .csproj file for this layer
    if [[ "$layer" == "Api" ]]; then
        csproj_path="$REPO_ROOT/src/${PREFIX}.Api/${PREFIX}.Api.csproj"
    elif [[ "$layer" == "Application" ]]; then
        csproj_path="$REPO_ROOT/src/${PREFIX}.Application/${PREFIX}.Application.csproj"
    elif [[ "$layer" == "Domain" ]]; then
        csproj_path="$REPO_ROOT/src/${PREFIX}.Domain/${PREFIX}.Domain.csproj"
    elif [[ "$layer" == "Infrastructure" ]]; then
        csproj_path="$REPO_ROOT/src/${PREFIX}.Infrastructure/${PREFIX}.Infrastructure.csproj"
    elif [[ "$layer" == "Tests.Common.Domain" ]]; then
        csproj_path="$REPO_ROOT/Tests/${PREFIX}.Tests.Common.Domain/${PREFIX}.Tests.Common.Domain.csproj"
    elif [[ "$layer" == "Tests.Common.Infrastructure" ]]; then
        csproj_path="$REPO_ROOT/Tests/${PREFIX}.Tests.Common.Infrastructure/${PREFIX}.Tests.Common.Infrastructure.csproj"
    elif [[ "$layer" == "Tests.Component" ]]; then
        csproj_path="$REPO_ROOT/Tests/${PREFIX}.Tests.Component/${PREFIX}.Tests.Component.csproj"
    elif [[ "$layer" == "Tests.System" ]]; then
        csproj_path="$REPO_ROOT/Tests/${PREFIX}.Tests.System/${PREFIX}.Tests.System.csproj"
    elif [[ "$layer" == "Tests.System.Domain" ]]; then
        csproj_path="$REPO_ROOT/Tests/${PREFIX}.Tests.System.Domain/${PREFIX}.Tests.System.Domain.csproj"
    elif [[ "$layer" == "Tests.System.Infrastructure" ]]; then
        csproj_path="$REPO_ROOT/Tests/${PREFIX}.Tests.System.Infrastructure/${PREFIX}.Tests.System.Infrastructure.csproj"
    fi

    if [[ -z "$csproj_path" || ! -f "$csproj_path" ]]; then
        return
    fi

    # Extract packages for this layer from team.json using awk (macOS-compatible)
    local packages=""
    packages=$(awk -v layer="$layer" '
        BEGIN { in_nugets=0; in_layer=0; in_arr=0 }
        /"nugets"[[:space:]]*:/ { in_nugets=1; next }
        in_nugets && !in_layer {
            key_pat = "\"" layer "\"[[:space:]]*:"
            if ($0 ~ key_pat) {
                in_layer=1
                if ($0 ~ /\[\]/) { exit }
                if ($0 ~ /\[/) { in_arr=1 }
                next
            }
        }
        in_layer && !in_arr && /\[/ { in_arr=1; next }
        in_layer && in_arr && /\]/ { exit }
        in_layer && in_arr && /"package"/ {
            line=$0
            gsub(/.*"package"[[:space:]]*:[[:space:]]*"/, "", line)
            split(line, parts, "\"")
            pkg=parts[1]
            line=$0
            gsub(/.*"version"[[:space:]]*:[[:space:]]*"/, "", line)
            split(line, parts2, "\"")
            ver=parts2[1]
            if (pkg != "" && ver != "") {
                printf "\t\t<PackageReference Include=\"%s\" Version=\"%s\" />\n", pkg, ver
            }
        }
    ' "$TEAM_JSON")

    if [[ -z "$packages" ]]; then
        action "Patch NuGets: $(basename "$csproj_path") (remove packages)"
        if ! $DRY_RUN; then
            awk '
                BEGIN { in_pkg_group=0; skip=0 }
                /<ItemGroup>/ {
                    save=$0
                    in_pkg_group=1
                    buffer=save"\n"
                    next
                }
                in_pkg_group && /<PackageReference/ { skip=1 }
                in_pkg_group && /<\/ItemGroup>/ {
                    if (!skip) { printf "%s", buffer; print }
                    in_pkg_group=0; skip=0; buffer=""
                    next
                }
                in_pkg_group { buffer=buffer $0 "\n"; next }
                { print }
            ' "$csproj_path" > "${csproj_path}.tmp" && mv "${csproj_path}.tmp" "$csproj_path"
        fi
    else
        action "Patch NuGets: $(basename "$csproj_path")"
        if ! $DRY_RUN; then
            local pkg_tmp
            pkg_tmp=$(mktemp)
            printf '%s\n' "$packages" > "$pkg_tmp"

            # Check if csproj already has PackageReference entries
            if grep -q '<PackageReference' "$csproj_path"; then
                # Replace existing PackageReference ItemGroup
                awk -v pkgfile="$pkg_tmp" '
                    BEGIN { replaced=0; in_pkg_group=0; buffer="" }
                    /<ItemGroup>/ && !replaced {
                        in_pkg_group=1
                        buffer=$0"\n"
                        next
                    }
                    in_pkg_group && /<PackageReference/ {
                        buffer=buffer $0 "\n"
                        next
                    }
                    in_pkg_group && /<\/ItemGroup>/ {
                        if (index(buffer, "PackageReference") > 0) {
                            print "\t<ItemGroup>"
                            while ((getline line < pkgfile) > 0) print line
                            close(pkgfile)
                            print "\t</ItemGroup>"
                            replaced=1
                        } else {
                            printf "%s", buffer
                            print
                        }
                        in_pkg_group=0; buffer=""
                        next
                    }
                    in_pkg_group { buffer=buffer $0 "\n"; next }
                    { print }
                ' "$csproj_path" > "${csproj_path}.tmp" && mv "${csproj_path}.tmp" "$csproj_path"
            else
                # No PackageReference exists — insert new ItemGroup after </PropertyGroup>
                awk -v pkgfile="$pkg_tmp" '
                    BEGIN { inserted=0 }
                    /<\/PropertyGroup>/ && !inserted {
                        print
                        print ""
                        print "\t<ItemGroup>"
                        while ((getline line < pkgfile) > 0) print line
                        close(pkgfile)
                        print "\t</ItemGroup>"
                        inserted=1
                        next
                    }
                    { print }
                ' "$csproj_path" > "${csproj_path}.tmp" && mv "${csproj_path}.tmp" "$csproj_path"
            fi

            rm -f "$pkg_tmp"
        fi
    fi
    ACTIONS_COUNT=$((ACTIONS_COUNT + 1))
}

# Process each layer defined in team.json nugets section
for layer in Api Application Domain Infrastructure Tests.Common.Domain Tests.Common.Infrastructure Tests.Component Tests.System Tests.System.Domain Tests.System.Infrastructure; do
    # Check if this layer has an entry in team.json
    if grep -q "\"$layer\"" "$TEAM_JSON" 2>/dev/null; then
        patch_nugets_for_layer "$layer"
    fi
done

echo ""

# =============================================================================
# Step 4: Cleanup — remove teams infrastructure
# =============================================================================

echo "--- Step 4: Cleanup ---"

action "Remove teams/ directory"
if ! $DRY_RUN; then
    rm -rf "$TEAMS_DIR"
fi

action "Remove teams.json"
if ! $DRY_RUN; then
    rm -f "$TEAMS_JSON"
fi

action "Remove .cursor/skills/core/service-init/"
if ! $DRY_RUN; then
    rm -rf "$REPO_ROOT/.cursor/skills/core/service-init"
fi

# Remove empty directories left behind
for dir in "$REPO_ROOT/.reference" "$REPO_ROOT/.cursor/skills/team" "$REPO_ROOT/.cursor/agents/team"; do
    if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
        action "Remove empty: ${dir#$REPO_ROOT/}"
        if ! $DRY_RUN; then
            rmdir "$dir" 2>/dev/null || true
        fi
    fi
done

ACTIONS_COUNT=$((ACTIONS_COUNT + 3))

echo ""

# =============================================================================
# Step 5: Generate multi-IDE outputs
# =============================================================================

echo "--- Step 5: Sync multi-IDE rules ---"

SYNC_SCRIPT="$SCRIPT_DIR/sync-ai-rules.sh"
if [[ -f "$SYNC_SCRIPT" ]]; then
    if $DRY_RUN; then
        action "Would run: sync-ai-rules.sh"
    else
        action "Running sync-ai-rules.sh..."
        bash "$SYNC_SCRIPT"
    fi
else
    echo "  Warning: sync-ai-rules.sh not found, skipping multi-IDE generation"
fi

echo ""

# =============================================================================
# Done
# =============================================================================

echo "============================================"
if $DRY_RUN; then
    echo "Dry run complete. No changes were made."
    echo "$ACTIONS_COUNT actions would be performed."
else
    echo "Team materialization complete!"
    echo "Team:    $TEAM_ID ($TEAM_NAME)"
    echo "Actions: $ACTIONS_COUNT"
    echo ""
    echo "Next steps:"
    echo "  1. Review the generated files"
    echo "  2. Update charts/values.yaml and .github/config.yaml with your team config"
fi
echo "============================================"
