# create a feature branch from plan file name if on the default branch (Codex port)
# usage: create-branch.ps1 <plan-file-path>
#        create-branch.ps1 --print-name <plan-file-path>
# exits 0 if branch created or already on feature branch; outputs branch name to stdout
#
# strips leading YYYYMMDD- date prefix from branch name since plan files use date prefixes
# VCS-aware: dispatches to git or hg based on detect-vcs.ps1

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-BranchNameFromPlan {
    param([string]$PlanFile)
    # e.g., docs/plans/20260329-feature-name.md -> feature-name
    $name = [System.IO.Path]::GetFileNameWithoutExtension($PlanFile)
    # strip leading date prefix if present (YYYYMMDD-, YYYY-MM-DD-, YYYYMM-DD- variants)
    $name = $name -replace '^\d{4}-?\d{2}-?\d{2}-', ''
    return $name
}

if ($args.Count -ge 1 -and $args[0] -eq '--print-name') {
    if ($args.Count -lt 2 -or [string]::IsNullOrWhiteSpace($args[1])) {
        Write-Error 'plan file path required'
        exit 1
    }
    Write-Output (Get-BranchNameFromPlan $args[1])
    exit 0
}

if ($args.Count -lt 1 -or [string]::IsNullOrWhiteSpace($args[0])) {
    Write-Error 'plan file path required'
    exit 1
}
$planFile = $args[0]

$vcs = & (Join-Path $scriptDir 'detect-vcs.ps1')
if ($LASTEXITCODE -ne 0) { exit 1 }

function Invoke-GitFlow {
    param([string]$Plan)

    $currentBranch = git branch --show-current
    if ($LASTEXITCODE -ne 0) { throw 'git branch --show-current failed' }

    # detect the default branch using local-first fallback chain (avoids network calls)
    $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $defaultBranch) {
        $defaultBranch = $defaultBranch -replace '^refs/remotes/origin/', ''
    } else {
        $defaultBranch = ''
    }
    if ([string]::IsNullOrEmpty($defaultBranch)) {
        foreach ($candidate in @('main', 'master', 'trunk', 'develop')) {
            git show-ref --verify --quiet "refs/heads/$candidate" *> $null
            if ($LASTEXITCODE -eq 0) { $defaultBranch = $candidate; break }
        }
    }
    if ([string]::IsNullOrEmpty($defaultBranch)) {
        $remoteShow = git remote show origin 2>$null
        if ($LASTEXITCODE -eq 0) {
            $headLine = $remoteShow | Select-String 'HEAD branch'
            if ($headLine) { $defaultBranch = (($headLine.ToString()) -replace '.*:\s*', '') }
        }
    }

    # if already on a feature branch, just report it
    if (-not [string]::IsNullOrEmpty($currentBranch) -and -not [string]::IsNullOrEmpty($defaultBranch) -and $currentBranch -ne $defaultBranch) {
        return $currentBranch
    }
    if (-not [string]::IsNullOrEmpty($currentBranch) -and [string]::IsNullOrEmpty($defaultBranch) -and $currentBranch -ne 'main' -and $currentBranch -ne 'master') {
        return $currentBranch
    }

    $branchName = Get-BranchNameFromPlan $Plan

    git show-ref --verify --quiet "refs/heads/$branchName" *> $null
    if ($LASTEXITCODE -eq 0) {
        git checkout $branchName | Out-Null
    } else {
        git checkout -b $branchName | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "git checkout failed for branch $branchName" }

    return $branchName
}

function Invoke-HgFlow {
    param([string]$Plan)

    # current active bookmark — modern-Mercurial equivalent of "current branch".
    $current = hg log -r . --template '{activebookmark}'
    if ($LASTEXITCODE -ne 0) { throw 'hg log failed' }

    # resolve the default branch so an active default bookmark is not mistaken for a feature branch
    $defaultBranch = & (Join-Path $scriptDir 'detect-branch.ps1') 2>$null
    if ($LASTEXITCODE -ne 0) { $defaultBranch = '' }
    $defaultBranch = ($defaultBranch -replace '^remote/', '')

    if (-not [string]::IsNullOrEmpty($current) -and -not [string]::IsNullOrEmpty($defaultBranch) -and $current -ne $defaultBranch) {
        return $current
    }
    if (-not [string]::IsNullOrEmpty($current) -and [string]::IsNullOrEmpty($defaultBranch) -and $current -ne 'main' -and $current -ne 'master') {
        return $current
    }

    $branchName = Get-BranchNameFromPlan $Plan

    # partial-run recovery: switch to existing bookmark, else create one on current commit
    $existing = hg book --template '{bookmark}' 2>$null
    $hasBookmark = $false
    if ($LASTEXITCODE -eq 0 -and $existing) {
        foreach ($line in ($existing -split "`n")) {
            if ($line.Trim() -eq $branchName) { $hasBookmark = $true; break }
        }
    }
    if ($hasBookmark) {
        hg update $branchName *> $null
    } else {
        hg book $branchName *> $null
    }
    if ($LASTEXITCODE -ne 0) { throw "hg bookmark/update failed for $branchName" }

    return $branchName
}

switch ($vcs) {
    'git' { Write-Output (Invoke-GitFlow $planFile) }
    'hg'  { Write-Output (Invoke-HgFlow $planFile) }
    default {
        Write-Error "unsupported VCS: $vcs"
        exit 1
    }
}
