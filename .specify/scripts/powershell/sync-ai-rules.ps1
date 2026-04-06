# =============================================================================
# sync-ai-rules.ps1 — Multi-IDE Rules Generator (PowerShell)
#
# Reads from .cursor/ (canonical source) and generates equivalent
# rules, skills, agents, and context files for:
#   - Claude Code  (.claude/, CLAUDE.md)
#   - Codex        (AGENTS.md)
#   - Copilot      (.github/instructions/, .github/agents/, .github/skills/)
#
# Usage:
#   ./sync-ai-rules.ps1                  # Generate all enabled targets
#   ./sync-ai-rules.ps1 -Target claude-code
#   ./sync-ai-rules.ps1 -Target codex
#   ./sync-ai-rules.ps1 -Target copilot
#   ./sync-ai-rules.ps1 -DryRun
#   ./sync-ai-rules.ps1 -Clean
# =============================================================================

param(
    [ValidateSet("claude-code", "codex", "copilot", "")]
    [string]$Target = "",
    [switch]$DryRun,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path "$ScriptDir/../../..").Path
$ConfigFile = Join-Path $RepoRoot ".ai-rules.json"
$CanonicalDir = Join-Path $RepoRoot ".cursor"

$Script:GeneratedCount = 0
$GeneratedHeaderComment = "<!-- AUTO-GENERATED from .cursor/ canonical source. Do not edit directly. -->"

# =============================================================================
# Configuration
# =============================================================================

function Load-Config {
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        exit 1
    }
    $script:Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    $script:ProjectName = $Config.project.name
    $script:ProjectDesc = $Config.project.description
    $script:ProjectTech = $Config.project.techStack
    $script:ClaudeEnabled = $Config.targets.'claude-code'.enabled
    $script:CodexEnabled = $Config.targets.codex.enabled
    $script:CopilotEnabled = $Config.targets.copilot.enabled
}

# =============================================================================
# Frontmatter Helpers
# =============================================================================

function Get-FrontmatterField {
    param([string]$FilePath, [string]$Field)
    $lines = Get-Content $FilePath
    $inFm = $false
    foreach ($line in $lines) {
        if ($line -match "^---\s*$") {
            if ($inFm) { return $null }
            $inFm = $true
            continue
        }
        if ($inFm -and $line -match "^${Field}:\s*(.+)$") {
            $val = $Matches[1].Trim()
            $val = $val -replace '^"', '' -replace '"$', ''
            return $val
        }
    }
    return $null
}

function Get-ContentWithoutFrontmatter {
    param([string]$FilePath)
    $lines = Get-Content $FilePath
    $inFm = $false
    $fmDone = $false
    $hasFm = $false
    $result = @()
    foreach ($line in $lines) {
        if ($line -match "^---\s*$" -and -not $fmDone) {
            if ($inFm) { $fmDone = $true; continue }
            $inFm = $true; $hasFm = $true; continue
        }
        if (-not $hasFm) { $result += $line; continue }
        if ($fmDone) { $result += $line }
    }
    $text = $result -join "`n"
    return $text.TrimStart("`n")
}

function Rewrite-Paths {
    param([string]$Content, [string]$From, [string]$To)
    return $Content.Replace($From, $To)
}

# =============================================================================
# File Helpers
# =============================================================================

function Get-GeneratedHeader {
    param([string]$SourcePath, [string]$RegenCmd = ".specify/scripts/powershell/sync-ai-rules.ps1")
    return @(
        $GeneratedHeaderComment
        "<!-- Source: $SourcePath | Regenerate: $RegenCmd -->"
        ""
    ) -join "`n"
}

function Write-GeneratedFile {
    param([string]$TargetPath, [string]$Content)
    if ($DryRun) {
        Write-Host "  [dry-run] Would write: $TargetPath"
        return
    }
    $dir = Split-Path -Parent $TargetPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $TargetPath -Value $Content -Encoding UTF8 -NoNewline
    $Script:GeneratedCount++
}

# =============================================================================
# Clean
# =============================================================================

function Invoke-Clean {
    Write-Host "Cleaning generated files..."

    $dirsToClean = @(
        (Join-Path $RepoRoot ".claude"),
        (Join-Path $RepoRoot ".codex"),
        (Join-Path $RepoRoot ".github/instructions"),
        (Join-Path $RepoRoot ".github/agents"),
        (Join-Path $RepoRoot ".github/skills")
    )
    $filesToClean = @(
        (Join-Path $RepoRoot "CLAUDE.md"),
        (Join-Path $RepoRoot "AGENTS.md")
    )

    foreach ($dir in $dirsToClean) {
        if (Test-Path $dir) {
            if ($DryRun) { Write-Host "  [dry-run] Would remove: $($dir.Replace($RepoRoot + [IO.Path]::DirectorySeparatorChar, ''))" }
            else { Remove-Item $dir -Recurse -Force; Write-Host "  Removed: $($dir.Replace($RepoRoot + [IO.Path]::DirectorySeparatorChar, ''))" }
        }
    }
    foreach ($file in $filesToClean) {
        if (Test-Path $file) {
            if ($DryRun) { Write-Host "  [dry-run] Would remove: $($file.Replace($RepoRoot + [IO.Path]::DirectorySeparatorChar, ''))" }
            else { Remove-Item $file -Force; Write-Host "  Removed: $($file.Replace($RepoRoot + [IO.Path]::DirectorySeparatorChar, ''))" }
        }
    }
    Write-Host "Clean complete."
}

# =============================================================================
# Claude Code Generator
# =============================================================================

function Generate-ClaudeRules {
    Write-Host "  Generating .claude/rules/..."
    $targetDir = Join-Path $RepoRoot ".claude/rules"

    foreach ($ruleFile in Get-ChildItem (Join-Path $CanonicalDir "rules") -Filter "*.mdc" -ErrorAction SilentlyContinue) {
        $baseName = $ruleFile.BaseName
        $relSource = ".cursor/rules/$($ruleFile.Name)"
        $description = Get-FrontmatterField $ruleFile.FullName "description"
        $body = Get-ContentWithoutFrontmatter $ruleFile.FullName
        $body = Rewrite-Paths $body ".cursor/agents/" ".claude/agents/"
        $body = Rewrite-Paths $body ".cursor/skills/" ".claude/skills/"

        $content = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target claude-code") + "`n"
        if ($description) { $content += "<!-- Description: $description -->`n`n" }
        $content += $body

        Write-GeneratedFile (Join-Path $targetDir "$baseName.md") $content
    }
}

function Generate-ClaudeSkills {
    Write-Host "  Generating .claude/skills/..."

    foreach ($tier in @("core", "team")) {
        $sourceDir = Join-Path $CanonicalDir "skills/$tier"
        if (-not (Test-Path $sourceDir)) { continue }

        foreach ($skillDir in Get-ChildItem $sourceDir -Directory) {
            $skillFile = Join-Path $skillDir.FullName "SKILL.md"
            if (-not (Test-Path $skillFile)) { continue }
            $relSource = ".cursor/skills/$tier/$($skillDir.Name)/SKILL.md"
            $body = Get-Content $skillFile -Raw
            $body = Rewrite-Paths $body ".cursor/skills/" ".claude/skills/"
            $body = Rewrite-Paths $body ".cursor/agents/" ".claude/agents/"

            $content = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target claude-code") + "`n"
            $content += $body

            Write-GeneratedFile (Join-Path $RepoRoot ".claude/skills/$tier/$($skillDir.Name)/SKILL.md") $content
        }
    }
}

function Generate-ClaudeAgents {
    Write-Host "  Generating .claude/agents/..."

    foreach ($tier in @("core", "team")) {
        $sourceDir = Join-Path $CanonicalDir "agents/$tier"
        if (-not (Test-Path $sourceDir)) { continue }

        foreach ($agentFile in Get-ChildItem $sourceDir -Filter "*.md") {
            $relSource = ".cursor/agents/$tier/$($agentFile.Name)"
            $name = Get-FrontmatterField $agentFile.FullName "name"
            $description = Get-FrontmatterField $agentFile.FullName "description"
            $body = Get-ContentWithoutFrontmatter $agentFile.FullName
            $body = Rewrite-Paths $body ".cursor/skills/" ".claude/skills/"
            $body = Rewrite-Paths $body ".cursor/agents/" ".claude/agents/"

            $content = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target claude-code") + "`n"
            if ($name -or $description) {
                $content += "---`n"
                if ($name) { $content += "name: $name`n" }
                if ($description) { $content += "description: $description`n" }
                $content += "---`n`n"
            }
            $content += $body

            Write-GeneratedFile (Join-Path $RepoRoot ".claude/agents/$tier/$($agentFile.Name)") $content
        }
    }
}

function Generate-ClaudeCommands {
    Write-Host "  Generating .claude/commands/..."
    $sourceDir = Join-Path $CanonicalDir "commands"
    if (-not (Test-Path $sourceDir)) { return }
    $targetDir = Join-Path $RepoRoot ".claude/commands"

    foreach ($cmdFile in Get-ChildItem $sourceDir -Filter "*.md" -ErrorAction SilentlyContinue) {
        $relSource = ".cursor/commands/$($cmdFile.Name)"
        $description = Get-FrontmatterField $cmdFile.FullName "description"
        $body = Get-ContentWithoutFrontmatter $cmdFile.FullName
        $body = Rewrite-Paths $body ".cursor/skills/" ".claude/skills/"
        $body = Rewrite-Paths $body ".cursor/agents/" ".claude/agents/"

        $content = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target claude-code") + "`n"
        if ($description) { $content += "<!-- Description: $description -->`n`n" }
        $content += $body

        Write-GeneratedFile (Join-Path $targetDir $cmdFile.Name) $content
    }
}

function Generate-ClaudeMd {
    Write-Host "  Generating CLAUDE.md..."

    $content = @"
$GeneratedHeaderComment
<!-- Regenerate: .specify/scripts/powershell/sync-ai-rules.ps1 -Target claude-code -->

# $ProjectName

$ProjectDesc

## Tech Stack

$ProjectTech

## Architecture Agents

Read the appropriate agent pair (core + team) based on the layer you are working in:

"@

    foreach ($agentFile in Get-ChildItem (Join-Path $CanonicalDir "agents/core") -Filter "*.md" | Sort-Object Name) {
        $name = Get-FrontmatterField $agentFile.FullName "name"
        $desc = Get-FrontmatterField $agentFile.FullName "description"
        $content += "### $name`n"
        if ($desc) { $content += "$desc`n" }
        $content += "- Core: ``.claude/agents/core/$($agentFile.Name)```n"
        $teamFile = Join-Path $CanonicalDir "agents/team/$($agentFile.Name)"
        if (Test-Path $teamFile) { $content += "- Team: ``.claude/agents/team/$($agentFile.Name)```n" }
        $content += "`n"
    }

    $content += "## Skills Reference`n`n"
    foreach ($tier in @("core", "team")) {
        $sourceDir = Join-Path $CanonicalDir "skills/$tier"
        if (-not (Test-Path $sourceDir)) { continue }
        $tierCap = (Get-Culture).TextInfo.ToTitleCase($tier)
        $content += "### $tierCap Skills`n`n"
        foreach ($skillDir in Get-ChildItem $sourceDir -Directory | Sort-Object Name) {
            $skillFile = Join-Path $skillDir.FullName "SKILL.md"
            if (-not (Test-Path $skillFile)) { continue }
            $content += "- **$($skillDir.Name)** (``.claude/skills/$tier/$($skillDir.Name)/SKILL.md``)`n"
        }
        $content += "`n"
    }

    $content += "## Key Conventions`n`n"
    foreach ($ruleFile in Get-ChildItem (Join-Path $CanonicalDir "rules") -Filter "*.mdc" | Sort-Object Name) {
        $baseName = $ruleFile.BaseName
        $desc = Get-FrontmatterField $ruleFile.FullName "description"
        $body = Get-ContentWithoutFrontmatter $ruleFile.FullName
        $body = Rewrite-Paths $body ".cursor/agents/" ".claude/agents/"
        $body = Rewrite-Paths $body ".cursor/skills/" ".claude/skills/"
        $content += "### $baseName`n"
        if ($desc) { $content += "$desc`n" }
        $content += "`n$body`n`n"
    }

    Write-GeneratedFile (Join-Path $RepoRoot "CLAUDE.md") $content
}

function Generate-ClaudeCode {
    Write-Host ""
    Write-Host "=== Claude Code ==="
    Generate-ClaudeRules
    Generate-ClaudeSkills
    Generate-ClaudeAgents
    Generate-ClaudeCommands
    Generate-ClaudeMd
}

# =============================================================================
# Codex Generator
# =============================================================================

function Rewrite-CodexPaths {
    param([string]$Content)
    $Content = $Content -replace '\.cursor/skills/(core|team)/([^/]+)/', '.codex/skills/$1-$2/'
    $Content = $Content -replace '\.cursor/agents/core/', '.codex/agents/core-'
    $Content = $Content -replace '\.cursor/agents/team/', '.codex/agents/team-'
    return $Content
}

function Generate-CodexRules {
    Write-Host "  Generating .codex/rules/..."
    $targetDir = Join-Path $RepoRoot ".codex/rules"
    foreach ($ruleFile in Get-ChildItem (Join-Path $CanonicalDir "rules") -Filter "*.mdc" -ErrorAction SilentlyContinue) {
        $relSource = ".cursor/rules/$($ruleFile.Name)"
        $body = Get-Content $ruleFile.FullName -Raw
        $body = Rewrite-CodexPaths $body
        $content = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target codex") + "`n$body"
        Write-GeneratedFile (Join-Path $targetDir $ruleFile.Name) $content
    }
}

function Generate-CodexSkills {
    Write-Host "  Generating .codex/skills/..."
    foreach ($tier in @("core", "team")) {
        $sourceDir = Join-Path $CanonicalDir "skills/$tier"
        if (-not (Test-Path $sourceDir)) { continue }
        foreach ($skillDir in Get-ChildItem $sourceDir -Directory | Sort-Object Name) {
            $skillFile = Join-Path $skillDir.FullName "SKILL.md"
            if (-not (Test-Path $skillFile)) { continue }
            $flatName = "$tier-$($skillDir.Name)"
            $relSource = ".cursor/skills/$tier/$($skillDir.Name)/SKILL.md"
            $body = Get-ContentWithoutFrontmatter $skillFile
            $body = Rewrite-CodexPaths $body
            $displayName = ($body -split "`n" | Where-Object { $_ -match '^# ' } | Select-Object -First 1) -replace '^# ', ''
            if (-not $displayName) { $displayName = $flatName }
            $description = Get-FrontmatterField $skillFile "description"

            # Extract first non-empty line under "## When to Use"
            $shortDesc = ""
            $captureWhenToUse = $false
            foreach ($line in ($body -split "`n")) {
                if ($line -match '^## When to Use') { $captureWhenToUse = $true; continue }
                if ($captureWhenToUse -and $line -match '^## ') { break }
                if ($captureWhenToUse) {
                    $trimmed = $line.Trim()
                    if ($trimmed) { $shortDesc = $trimmed; break }
                }
            }
            if (-not $shortDesc) { $shortDesc = $description }
            if (-not $shortDesc) { $shortDesc = "$flatName skill" }

            $skillDesc = if ($description) { $description } else { $shortDesc }
            $escapedSkillDesc = $skillDesc -replace '"', '\"'
            $escapedShortDesc = $shortDesc -replace '"', '\"'
            $escapedDisplayName = $displayName -replace '"', '\"'
            $truncatedShortDesc = if ($shortDesc.Length -gt 64) { $shortDesc.Substring(0, 64) } else { $shortDesc }
            $escapedTruncatedShortDesc = $truncatedShortDesc -replace '"', '\"'

            $skillContent = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target codex") + "`n"
            $skillContent += "---`nname: `"$flatName`"`ndescription: `"$escapedSkillDesc`"`nmetadata:`n  short-description: `"$escapedShortDesc`"`n---`n`n$body"
            Write-GeneratedFile (Join-Path $RepoRoot ".codex/skills/$flatName/SKILL.md") $skillContent

            $yamlContent = "interface:`n  display_name: `"$escapedDisplayName`"`n  short_description: `"$escapedTruncatedShortDesc`""
            Write-GeneratedFile (Join-Path $RepoRoot ".codex/skills/$flatName/agents/openai.yaml") $yamlContent
        }
    }
}

function Generate-CodexAgents {
    Write-Host "  Generating .codex/agents/..."
    foreach ($tier in @("core", "team")) {
        $sourceDir = Join-Path $CanonicalDir "agents/$tier"
        if (-not (Test-Path $sourceDir)) { continue }
        foreach ($agentFile in Get-ChildItem $sourceDir -Filter "*.md" | Sort-Object Name) {
            $baseName = $agentFile.BaseName
            $relSource = ".cursor/agents/$tier/$($agentFile.Name)"
            $name = Get-FrontmatterField $agentFile.FullName "name"
            $desc = Get-FrontmatterField $agentFile.FullName "description"
            $body = Get-ContentWithoutFrontmatter $agentFile.FullName
            $body = Rewrite-CodexPaths $body
            $content = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target codex") + "`n"
            $content += "---`nname: $name`ndescription: `"$desc`"`n---`n`n$body"
            Write-GeneratedFile (Join-Path $RepoRoot ".codex/agents/$tier-$baseName.md") $content
        }
    }
}

function Generate-CodexCommands {
    Write-Host "  Generating .codex/commands/..."
    $sourceDir = Join-Path $CanonicalDir "commands"
    if (-not (Test-Path $sourceDir)) { return }
    $targetDir = Join-Path $RepoRoot ".codex/commands"

    foreach ($cmdFile in Get-ChildItem $sourceDir -Filter "*.md" -ErrorAction SilentlyContinue) {
        $relSource = ".cursor/commands/$($cmdFile.Name)"
        $description = Get-FrontmatterField $cmdFile.FullName "description"
        $body = Get-ContentWithoutFrontmatter $cmdFile.FullName
        $body = Rewrite-Paths $body ".cursor/skills/" ".codex/skills/"
        $body = Rewrite-Paths $body ".cursor/agents/" ".codex/agents/"

        $content = ""
        if ($description) {
            $escapedDescription = $description -replace '"', '\"'
            $content += "---`ndescription: `"$escapedDescription`"`n---`n`n"
        }
        $content += (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target codex") + "`n"
        $content += $body

        Write-GeneratedFile (Join-Path $targetDir $cmdFile.Name) $content
    }
}

function Generate-AgentsMd {
    Write-Host "  Generating AGENTS.md..."
    $content = @"
$GeneratedHeaderComment
<!-- Regenerate: .specify/scripts/powershell/sync-ai-rules.ps1 -Target codex -->

# $ProjectName

$ProjectDesc

**Tech Stack:** $ProjectTech

## Architecture Agents

Read the appropriate agent based on the layer you are working in. Each role has a core (architecture) and team (library-specific) variant in ``.codex/agents/``.

"@
    foreach ($agentFile in Get-ChildItem (Join-Path $CanonicalDir "agents/core") -Filter "*.md" | Sort-Object Name) {
        $baseName = $agentFile.BaseName
        $name = Get-FrontmatterField $agentFile.FullName "name"
        $desc = Get-FrontmatterField $agentFile.FullName "description"
        $content += "### $name`n$desc`n- Core: ``.codex/agents/core-$baseName.md```n"
        $teamFile = Join-Path $CanonicalDir "agents/team/$($agentFile.Name)"
        if (Test-Path $teamFile) { $content += "- Team: ``.codex/agents/team-$baseName.md```n" }
        $content += "`n"
    }

    $content += "## Skills Reference`n`nSkills are in ``.codex/skills/``. Invoke with ``$`skill-name`` in Codex.`n`n"
    foreach ($tier in @("core", "team")) {
        $sourceDir = Join-Path $CanonicalDir "skills/$tier"
        if (-not (Test-Path $sourceDir)) { continue }
        $tierCap = (Get-Culture).TextInfo.ToTitleCase($tier)
        $content += "### $tierCap Skills`n`n"
        foreach ($skillDir in Get-ChildItem $sourceDir -Directory | Sort-Object Name) {
            $skillFile = Join-Path $skillDir.FullName "SKILL.md"
            if (-not (Test-Path $skillFile)) { continue }
            $flatName = "$tier-$($skillDir.Name)"
            $content += "- **``$`$flatName``** (``.codex/skills/$flatName/SKILL.md``)`n"
        }
        $content += "`n"
    }

    $content += "## Key Conventions`n`n"
    foreach ($ruleFile in Get-ChildItem (Join-Path $CanonicalDir "rules") -Filter "*.mdc" | Sort-Object Name) {
        $baseName = $ruleFile.BaseName
        $desc = Get-FrontmatterField $ruleFile.FullName "description"
        $body = Get-ContentWithoutFrontmatter $ruleFile.FullName
        $body = Rewrite-CodexPaths $body
        $content += "### $baseName`n"
        if ($desc) { $content += "$desc`n" }
        $content += "`n$body`n`n"
    }

    Write-GeneratedFile (Join-Path $RepoRoot "AGENTS.md") $content
}

function Generate-Codex {
    Write-Host ""
    Write-Host "=== Codex ==="
    Generate-CodexRules
    Generate-CodexSkills
    Generate-CodexAgents
    Generate-CodexCommands
    Generate-AgentsMd
}

# =============================================================================
# GitHub Copilot Generator
# =============================================================================

function Generate-CopilotInstructions {
    Write-Host "  Generating .github/instructions/..."
    $targetDir = Join-Path $RepoRoot ".github/instructions"

    foreach ($ruleFile in Get-ChildItem (Join-Path $CanonicalDir "rules") -Filter "*.mdc" -ErrorAction SilentlyContinue) {
        $baseName = $ruleFile.BaseName
        $relSource = ".cursor/rules/$($ruleFile.Name)"
        $description = Get-FrontmatterField $ruleFile.FullName "description"
        $globs = Get-FrontmatterField $ruleFile.FullName "globs"
        $applyTo = $globs -replace '[\[\]"]', '' -replace ',\s*', ','
        $body = Get-ContentWithoutFrontmatter $ruleFile.FullName
        $body = Rewrite-Paths $body ".cursor/agents/" ".github/agents/"
        $body = Rewrite-Paths $body ".cursor/skills/" ".github/skills/"

        $content = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target copilot") + "`n"
        $content += "---`napplyTo: `"$applyTo`"`n---`n`n"
        if ($description) { $content += "# $baseName`n$description`n`n" }
        $content += $body

        Write-GeneratedFile (Join-Path $targetDir "$baseName.instructions.md") $content
    }
}

function Generate-CopilotAgents {
    Write-Host "  Generating .github/agents/..."
    $targetDir = Join-Path $RepoRoot ".github/agents"

    foreach ($tier in @("core", "team")) {
        $sourceDir = Join-Path $CanonicalDir "agents/$tier"
        if (-not (Test-Path $sourceDir)) { continue }

        foreach ($agentFile in Get-ChildItem $sourceDir -Filter "*.md") {
            $baseName = $agentFile.BaseName
            $relSource = ".cursor/agents/$tier/$($agentFile.Name)"
            $description = Get-FrontmatterField $agentFile.FullName "description"
            $body = Get-ContentWithoutFrontmatter $agentFile.FullName
            $body = Rewrite-Paths $body ".cursor/skills/" ".github/skills/"
            $body = Rewrite-Paths $body ".cursor/agents/" ".github/agents/"

            $content = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target copilot") + "`n"
            $content += "---`ndescription: `"$description`"`n---`n`n"
            $content += $body

            Write-GeneratedFile (Join-Path $targetDir "$tier-$baseName.agent.md") $content
        }
    }
}

function Generate-CopilotSkills {
    Write-Host "  Generating .github/skills/..."

    foreach ($tier in @("core", "team")) {
        $sourceDir = Join-Path $CanonicalDir "skills/$tier"
        if (-not (Test-Path $sourceDir)) { continue }

        foreach ($skillDir in Get-ChildItem $sourceDir -Directory) {
            $skillFile = Join-Path $skillDir.FullName "SKILL.md"
            if (-not (Test-Path $skillFile)) { continue }
            $relSource = ".cursor/skills/$tier/$($skillDir.Name)/SKILL.md"
            $body = Get-Content $skillFile -Raw
            $body = Rewrite-Paths $body ".cursor/skills/" ".github/skills/"
            $body = Rewrite-Paths $body ".cursor/agents/" ".github/agents/"

            $content = (Get-GeneratedHeader $relSource ".specify/scripts/powershell/sync-ai-rules.ps1 -Target copilot") + "`n"
            $content += $body

            Write-GeneratedFile (Join-Path $RepoRoot ".github/skills/$tier/$($skillDir.Name)/SKILL.md") $content
        }
    }
}

function Generate-Copilot {
    Write-Host ""
    Write-Host "=== GitHub Copilot ==="
    Generate-CopilotInstructions
    Generate-CopilotAgents
    Generate-CopilotSkills
}

# =============================================================================
# Main
# =============================================================================

Write-Host "sync-ai-rules: Multi-IDE Rules Generator"
Write-Host "========================================="

if ($Clean) {
    Invoke-Clean
    exit 0
}

if (-not (Test-Path $CanonicalDir)) {
    Write-Error "Canonical source not found: $CanonicalDir"
    exit 1
}

Load-Config

Write-Host "Project: $ProjectName"
Write-Host "Canonical: .cursor/"
if ($DryRun) { Write-Host "Mode: DRY RUN (no files will be written)" }

$ranAny = $false

if (-not $Target -or $Target -eq "claude-code") {
    if ($ClaudeEnabled -or $Target -eq "claude-code") {
        Generate-ClaudeCode
        $ranAny = $true
    }
}

if (-not $Target -or $Target -eq "codex") {
    if ($CodexEnabled -or $Target -eq "codex") {
        Generate-Codex
        $ranAny = $true
    }
}

if (-not $Target -or $Target -eq "copilot") {
    if ($CopilotEnabled -or $Target -eq "copilot") {
        Generate-Copilot
        $ranAny = $true
    }
}

if (-not $ranAny) {
    Write-Host ""
    Write-Host "No targets enabled. Check .ai-rules.json targets configuration."
    exit 1
}

Write-Host ""
Write-Host "========================================="
if ($DryRun) {
    Write-Host "Dry run complete. No files were written."
} else {
    Write-Host "Generation complete. $($Script:GeneratedCount) files written."
}
