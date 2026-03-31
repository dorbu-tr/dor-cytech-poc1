#!/usr/bin/env pwsh
# Common PowerShell functions analogous to common.sh

function Get-RepoRoot {
    try {
        $result = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }
    
    # Fall back to script location for non-git repos
    return (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
}

function Find-LatestFeatureDir {
    param([string]$RepoRoot)
    $specsDir = Join-Path $RepoRoot "specs"
    if (Test-Path $specsDir) {
        $latestFeature = ""
        $highest = 0
        Get-ChildItem -Path $specsDir -Directory | ForEach-Object {
            if ($_.Name -match '^(\d{3})-') {
                $num = [int]$matches[1]
                if ($num -gt $highest) {
                    $highest = $num
                    $latestFeature = $_.Name
                }
            }
        }
        if ($latestFeature) { return $latestFeature }
    }
    return $null
}

function Get-CurrentBranch {
    # First check if SPECIFY_FEATURE environment variable is set
    if ($env:SPECIFY_FEATURE) {
        return $env:SPECIFY_FEATURE
    }
    
    # Then check git if available
    $gitBranch = $null
    try {
        $result = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            $gitBranch = $result
        }
    } catch {
        # Git command failed
    }
    
    # If git branch is a feature branch (###-*), use it directly
    if ($gitBranch -and $gitBranch -match '^[0-9]{3}-') {
        return $gitBranch
    }
    
    # Git branch is non-feature (e.g. main) or unavailable — find latest feature dir in specs/
    $repoRoot = Get-RepoRoot
    $latest = Find-LatestFeatureDir -RepoRoot $repoRoot
    if ($latest) { return $latest }
    
    # Final fallback: return git branch or "main"
    if ($gitBranch) { return $gitBranch }
    return "main"
}

function Test-HasGit {
    try {
        git rev-parse --show-toplevel 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-FeatureBranch {
    param(
        [string]$Branch,
        [bool]$HasGit = $true
    )
    
    # For non-git repos, we can't enforce branch naming but still provide output
    if (-not $HasGit) {
        Write-Warning "[specify] Warning: Git repository not detected; skipped branch validation"
        return $true
    }
    
    if ($Branch -notmatch '^[0-9]{3}-') {
        Write-Output "ERROR: Not on a feature branch. Current branch: $Branch"
        Write-Output "Feature branches should be named like: 001-feature-name"
        return $false
    }
    return $true
}

function Get-FeatureDir {
    param([string]$RepoRoot, [string]$Branch)
    Join-Path $RepoRoot "specs/$Branch"
}

function Find-FeatureDirByPrefix {
    param([string]$RepoRoot, [string]$BranchName)
    $specsDir = Join-Path $RepoRoot "specs"

    if ($BranchName -notmatch '^(\d{3})-') {
        return Join-Path $specsDir $BranchName
    }

    $prefix = $matches[1]
    $matchedDirs = @()
    if (Test-Path $specsDir) {
        Get-ChildItem -Path $specsDir -Directory | Where-Object { $_.Name -match "^$prefix-" } | ForEach-Object {
            $matchedDirs += $_.Name
        }
    }

    if ($matchedDirs.Count -eq 1) {
        return Join-Path $specsDir $matchedDirs[0]
    } elseif ($matchedDirs.Count -gt 1) {
        Write-Warning "Multiple spec directories found with prefix '$prefix': $($matchedDirs -join ', ')"
    }
    return Join-Path $specsDir $BranchName
}

function Get-FeaturePathsEnv {
    $repoRoot = Get-RepoRoot
    $currentBranch = Get-CurrentBranch
    $hasGit = Test-HasGit
    $featureDir = Find-FeatureDirByPrefix -RepoRoot $repoRoot -BranchName $currentBranch
    
    [PSCustomObject]@{
        REPO_ROOT     = $repoRoot
        CURRENT_BRANCH = $currentBranch
        HAS_GIT       = $hasGit
        FEATURE_DIR   = $featureDir
        FEATURE_SPEC  = Join-Path $featureDir 'spec.md'
        IMPL_PLAN     = Join-Path $featureDir 'plan.md'
        TASKS         = Join-Path $featureDir 'tasks.md'
        RESEARCH      = Join-Path $featureDir 'research.md'
        DATA_MODEL    = Join-Path $featureDir 'data-model.md'
        QUICKSTART    = Join-Path $featureDir 'quickstart.md'
        CONTRACTS_DIR = Join-Path $featureDir 'contracts'
    }
}

function Test-FileExists {
    param([string]$Path, [string]$Description)
    if (Test-Path -Path $Path -PathType Leaf) {
        Write-Output "  ✓ $Description"
        return $true
    } else {
        Write-Output "  ✗ $Description"
        return $false
    }
}

function Test-DirHasFiles {
    param([string]$Path, [string]$Description)
    if ((Test-Path -Path $Path -PathType Container) -and (Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1)) {
        Write-Output "  ✓ $Description"
        return $true
    } else {
        Write-Output "  ✗ $Description"
        return $false
    }
}

