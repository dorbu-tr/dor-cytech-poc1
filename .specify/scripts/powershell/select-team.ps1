# =============================================================================
# select-team.ps1 — Team Materialization Script (PowerShell)
#
# Transforms the unified multi-team template into a single-team template by:
#   1. Copying team-specific AI content (skills, agents, constitution, reference)
#   2. Overlaying team-specific source files (KEEP files)
#   2.5. Removing team-excluded files (from "remove" in team.json)
#   3. Replacing NuGet packages in .csproj files
#   4. Removing all other teams and the teams/ infrastructure
#   5. Running sync-ai-rules.ps1 to generate multi-IDE outputs
#
# This is a ONE-TIME, DESTRUCTIVE operation.
#
# Usage:
#   .\select-team.ps1 <team-id>         # Materialize for a team
#   .\select-team.ps1 -List             # List available teams
#   .\select-team.ps1 -DryRun <team>    # Preview without writing
# =============================================================================

param(
    [Parameter(Position=0)]
    [string]$TeamId,
    [switch]$List,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path "$ScriptDir\..\..\..").Path
$TeamsDir = Join-Path $RepoRoot "teams"
$TeamsJson = Join-Path $RepoRoot "teams.json"
$Prefix = "dor-cytech-poc1"

$ActionsCount = 0

# =============================================================================
# Help
# =============================================================================

if ($Help) {
    Write-Host "Usage: .\select-team.ps1 [options] <team-id>"
    Write-Host ""
    Write-Host "Materializes the unified template for a specific team."
    Write-Host "This is a ONE-TIME, DESTRUCTIVE operation."
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  <team-id>       Materialize the template for the given team"
    Write-Host "  -List           List available teams"
    Write-Host "  -DryRun         Preview changes without writing"
    Write-Host "  -Help           Show this help"
    exit 0
}

# =============================================================================
# List teams
# =============================================================================

if ($List) {
    if (-not (Test-Path $TeamsJson)) {
        Write-Host "Error: teams.json not found. Has select-team already been run?"
        exit 1
    }
    $teams = (Get-Content $TeamsJson -Raw | ConvertFrom-Json).teams
    Write-Host "Available teams:"
    Write-Host ""
    foreach ($t in $teams) {
        Write-Host ("  {0,-15} {1} - {2}" -f $t.id, $t.name, $t.description)
    }
    exit 0
}

# =============================================================================
# Validation
# =============================================================================

if (-not $TeamId) {
    Write-Host "Error: No team specified."
    Write-Host "Usage: .\select-team.ps1 <team-id>"
    Write-Host "Run with -List to see available teams."
    exit 1
}

$TeamDir = Join-Path $TeamsDir $TeamId
if (-not (Test-Path $TeamDir)) {
    Write-Host "Error: Team '$TeamId' not found in teams/"
    Write-Host "Available teams:"
    Get-ChildItem $TeamsDir -Directory | ForEach-Object { Write-Host "  $($_.Name)" }
    exit 1
}

$TeamJsonPath = Join-Path $TeamDir "team.json"
if (-not (Test-Path $TeamJsonPath)) {
    Write-Host "Error: team.json not found for team '$TeamId'"
    exit 1
}

$TeamConfig = Get-Content $TeamJsonPath -Raw | ConvertFrom-Json
$TeamName = $TeamConfig.name

Write-Host "============================================"
Write-Host "select-team: Team Materialization"
Write-Host "============================================"
Write-Host "Team:     $TeamId ($TeamName)"
Write-Host "Repo:     $RepoRoot"
if ($DryRun) {
    Write-Host "Mode:     DRY RUN (no changes will be made)"
}
Write-Host ""

function Do-Action {
    param([string]$Message)
    if ($DryRun) {
        Write-Host "  [dry-run] $Message"
    } else {
        Write-Host "  $Message"
    }
}

# =============================================================================
# Step 1: Copy AI content
# =============================================================================

Write-Host "--- Step 1: Copy team AI content ---"

# Skills
$SkillsDir = Join-Path $TeamDir "skills"
if (Test-Path $SkillsDir) {
    Do-Action "Copy skills -> .cursor/skills/team/"
    if (-not $DryRun) {
        $target = Join-Path $RepoRoot ".cursor\skills\team"
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Copy-Item -Path "$SkillsDir\*" -Destination $target -Recurse -Force
    }
    $script:ActionsCount++
}

# Agents
$AgentsDir = Join-Path $TeamDir "agents"
if (Test-Path $AgentsDir) {
    Do-Action "Copy agents -> .cursor/agents/team/"
    if (-not $DryRun) {
        $target = Join-Path $RepoRoot ".cursor\agents\team"
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Copy-Item -Path "$AgentsDir\*" -Destination $target -Recurse -Force
    }
    $script:ActionsCount++
}

# Constitution
$ConstitutionFile = Join-Path $TeamDir "constitution-team.md"
if (Test-Path $ConstitutionFile) {
    Do-Action "Copy constitution-team.md -> .specify/memory/"
    if (-not $DryRun) {
        Copy-Item $ConstitutionFile (Join-Path $RepoRoot ".specify\memory\constitution-team.md") -Force
    }
    $script:ActionsCount++
}

# Reference
$RefDir = Join-Path $TeamDir "reference"
if (Test-Path $RefDir) {
    Do-Action "Copy reference/ -> .reference/"
    if (-not $DryRun) {
        $target = Join-Path $RepoRoot ".reference"
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Copy-Item -Path "$RefDir\*" -Destination $target -Recurse -Force
    }
    $script:ActionsCount++
}

Write-Host ""

# =============================================================================
# Step 1.5: Clone example projects to .examples/
# =============================================================================

Write-Host "--- Step 1.5: Clone team example projects ---"

$ExamplesDir = Join-Path $RepoRoot ".examples"
$examples = $TeamConfig.examples

if ($examples -and $examples.Count -gt 0) {
    foreach ($example in $examples) {
        $exampleDir = Join-Path $ExamplesDir $example.name
        Do-Action "Clone example: $($example.name) -> .examples/$($example.name)"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path $ExamplesDir | Out-Null
            try {
                if (Get-Command gh -ErrorAction SilentlyContinue) {
                    & gh repo clone $example.url $exampleDir -- --depth 1 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        git clone --depth 1 $example.url $exampleDir 2>$null
                    }
                } else {
                    git clone --depth 1 $example.url $exampleDir 2>$null
                }
                # Remove .git to save space
                $gitDir = Join-Path $exampleDir ".git"
                if (Test-Path $gitDir) {
                    Remove-Item $gitDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Host "  Warning: Failed to clone $($example.name) ($($example.url)) - skipping"
            }
        }
        $script:ActionsCount++
    }
} else {
    Write-Host "  (no example projects defined for this team)"
}

Write-Host ""

# =============================================================================
# Step 2: Overlay source files (KEEP files)
# =============================================================================

Write-Host "--- Step 2: Overlay team source files ---"

$SrcDir = Join-Path $TeamDir "src"
if (Test-Path $SrcDir) {
    foreach ($layerDir in Get-ChildItem $SrcDir -Directory) {
        $layerName = $layerDir.Name
        if ($layerName -like "Tests.*") {
            $projectDir = Join-Path $RepoRoot "Tests\$Prefix.$layerName"
        } else {
            $projectDir = Join-Path $RepoRoot "src\$Prefix.$layerName"
        }

        if (-not (Test-Path $projectDir)) {
            Write-Host "  Warning: Project directory not found for layer '$layerName': $projectDir"
            continue
        }

        foreach ($file in Get-ChildItem $layerDir.FullName -Recurse -File) {
            $relPath = $file.FullName.Substring($layerDir.FullName.Length + 1)
            $targetFile = Join-Path $projectDir $relPath
            Do-Action "Overlay: $Prefix.$layerName\$relPath"
            if (-not $DryRun) {
                $targetDir = Split-Path $targetFile -Parent
                New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
                Copy-Item $file.FullName $targetFile -Force
            }
            $script:ActionsCount++
        }
    }
} else {
    Write-Host "  (no source overlay for this team)"
}

Write-Host ""

# =============================================================================
# Step 2.5: Remove team-excluded files
# =============================================================================

Write-Host "--- Step 2.5: Remove team-excluded files ---"

$removeConfig = $TeamConfig.remove
$removeCount = 0

if ($removeConfig) {
    foreach ($layer in ($removeConfig | Get-Member -MemberType NoteProperty).Name) {
        $files = $removeConfig.$layer
        foreach ($file in $files) {
            if ($layer -like "Tests.*") {
                $targetPath = Join-Path $RepoRoot "Tests\$Prefix.$layer\$file"
            } else {
                $targetPath = Join-Path $RepoRoot "src\$Prefix.$layer\$file"
            }
            if (Test-Path $targetPath) {
                Do-Action "Remove: $Prefix.$layer\$file"
                if (-not $DryRun) {
                    Remove-Item $targetPath -Force
                }
                $removeCount++
                $script:ActionsCount++
            }
        }
    }
}

if ($removeCount -eq 0) {
    Write-Host "  (no files to remove for this team)"
}

Write-Host ""

# =============================================================================
# Step 3: Patch NuGet packages in .csproj files
# =============================================================================

Write-Host "--- Step 3: Patch NuGet packages ---"

$LayerMap = @{
    "Api" = "$Prefix.Api"
    "Application" = "$Prefix.Application"
    "Domain" = "$Prefix.Domain"
    "Infrastructure" = "$Prefix.Infrastructure"
    "Tests.Common.Domain" = "$Prefix.Tests.Common.Domain"
    "Tests.Common.Infrastructure" = "$Prefix.Tests.Common.Infrastructure"
    "Tests.Component" = "$Prefix.Tests.Component"
    "Tests.System" = "$Prefix.Tests.System"
    "Tests.System.Domain" = "$Prefix.Tests.System.Domain"
    "Tests.System.Infrastructure" = "$Prefix.Tests.System.Infrastructure"
}

$nugets = $TeamConfig.nugets
if ($nugets) {
    foreach ($layer in $LayerMap.Keys) {
        $packages = $nugets.$layer
        if ($null -eq $packages) { continue }

        $projectName = $LayerMap[$layer]
        if ($layer -like "Tests.*") {
            $csprojPath = Join-Path $RepoRoot "Tests\$projectName\$projectName.csproj"
        } else {
            $csprojPath = Join-Path $RepoRoot "src\$projectName\$projectName.csproj"
        }
        if (-not (Test-Path $csprojPath)) { continue }

        Do-Action "Patch NuGets: $(Split-Path $csprojPath -Leaf)"

        if (-not $DryRun) {
            [xml]$xml = Get-Content $csprojPath
            # Find and remove the first ItemGroup with PackageReference
            $pkgGroup = $xml.Project.ItemGroup | Where-Object { $_.PackageReference } | Select-Object -First 1

            if ($packages.Count -eq 0) {
                # Empty package list — remove the ItemGroup
                if ($pkgGroup) {
                    $pkgGroup.ParentNode.RemoveChild($pkgGroup) | Out-Null
                }
            } else {
                if (-not $pkgGroup) {
                    # Create new ItemGroup if none exists
                    $pkgGroup = $xml.CreateElement("ItemGroup")
                    $xml.Project.PrependChild($pkgGroup) | Out-Null
                } else {
                    $pkgGroup.RemoveAll()
                }
                foreach ($pkg in $packages) {
                    $ref = $xml.CreateElement("PackageReference")
                    $ref.SetAttribute("Include", $pkg.package)
                    $ref.SetAttribute("Version", $pkg.version)
                    $pkgGroup.AppendChild($ref) | Out-Null
                }
            }

            $settings = New-Object System.Xml.XmlWriterSettings
            $settings.Indent = $true
            $settings.IndentChars = "`t"
            $settings.OmitXmlDeclaration = $true
            $writer = [System.Xml.XmlWriter]::Create($csprojPath, $settings)
            $xml.Save($writer)
            $writer.Close()
        }
        $script:ActionsCount++
    }
}

Write-Host ""

# =============================================================================
# Step 4: Cleanup
# =============================================================================

Write-Host "--- Step 4: Cleanup ---"

Do-Action "Remove teams/ directory"
if (-not $DryRun) {
    Remove-Item $TeamsDir -Recurse -Force -ErrorAction SilentlyContinue
}

Do-Action "Remove teams.json"
if (-not $DryRun) {
    Remove-Item $TeamsJson -Force -ErrorAction SilentlyContinue
}

$script:ActionsCount += 2
Write-Host ""

# =============================================================================
# Step 5: Sync multi-IDE rules
# =============================================================================

Write-Host "--- Step 5: Sync multi-IDE rules ---"

$SyncScript = Join-Path $ScriptDir "sync-ai-rules.ps1"
if (Test-Path $SyncScript) {
    if ($DryRun) {
        Do-Action "Would run: sync-ai-rules.ps1"
    } else {
        Do-Action "Running sync-ai-rules.ps1..."
        & $SyncScript
    }
} else {
    Write-Host "  Warning: sync-ai-rules.ps1 not found, skipping multi-IDE generation"
}

Write-Host ""

# =============================================================================
# Done
# =============================================================================

Write-Host "============================================"
if ($DryRun) {
    Write-Host "Dry run complete. No changes were made."
    Write-Host "$ActionsCount actions would be performed."
} else {
    Write-Host "Team materialization complete!"
    Write-Host "Team:    $TeamId ($TeamName)"
    Write-Host "Actions: $ActionsCount"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Review the generated files"
    Write-Host "  2. Update charts/values.yaml and .github/config.yaml with your team config"
}
Write-Host "============================================"
