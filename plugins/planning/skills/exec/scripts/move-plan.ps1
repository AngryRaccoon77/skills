# move a completed plan file into its sibling completed/ directory and commit it (Codex port)
# usage: move-plan.ps1 <plan-file-path>
# no-op if the plan is already under completed/ or the file is missing
# VCS-aware commit via stage-and-commit.ps1; does NOT push

$ErrorActionPreference = 'Stop'

if ($args.Count -lt 1) {
    Write-Error 'usage: move-plan.ps1 <plan-file-path>'
    exit 1
}

$plan = $args[0]
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# VCS-awareness for the tracking checks below
$vcs = & (Join-Path $scriptDir 'detect-vcs.ps1')
if ($LASTEXITCODE -ne 0) { exit 1 }

# already under completed/ — nothing to do
if ($plan -match '[\\/]completed[\\/]') {
    Write-Output "plan already under completed/: $plan"
    exit 0
}

# file missing (already moved, or never existed) — nothing to do
if (-not (Test-Path -LiteralPath $plan -PathType Leaf)) {
    Write-Output "plan file not found, skipping move: $plan"
    exit 0
}

$base = [System.IO.Path]::GetFileName($plan)
$destDir = Join-Path (Split-Path -Parent $plan) 'completed'
$dest = Join-Path $destDir $base

# refuse to clobber an existing completed plan with the same name
if (Test-Path -LiteralPath $dest) {
    Write-Error "destination already exists, refusing to overwrite: $dest"
    exit 1
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Move-Item -LiteralPath $plan -Destination $dest

# stage-and-commit.ps1 stages both the (now-removed) old path and the new path;
# git and hg each record this as the rename plus commit.
# Robustness deviation from upstream: a plan that was never committed makes the
# old path unknown to git ("pathspec did not match"), which would abort the whole
# commit even though the move already happened. Only pass paths that exist on
# disk or are actually tracked by the current VCS.
# NOTE: the outer @(...) keeps $paths an array even for a single match — a bare
# scalar string would splat char-by-char at the stage-and-commit call below.
$paths = @(@($plan, $dest) | Where-Object {
    if (Test-Path -LiteralPath $_) { return $true }
    # NOTE: an if/elseif chain, not a switch — a switch clause's boolean output
    # does not survive as this filter block's output, silently dropping paths.
    if ($vcs -eq 'git') {
        git ls-files --error-unmatch -- "$_" *> $null
        $LASTEXITCODE -eq 0
    } elseif ($vcs -eq 'hg') {
        hg files -q "$_" *> $null
        $LASTEXITCODE -eq 0
    } else {
        $false
    }
})
if ($paths.Count -gt 0) {
    & (Join-Path $scriptDir 'stage-and-commit.ps1') "docs: move completed plan $base to completed/" @paths
    if ($LASTEXITCODE -ne 0) { throw 'stage-and-commit failed' }
} else {
    Write-Output 'nothing tracked to commit (plan was not under version control)'
}

Write-Output "moved plan to $dest"
