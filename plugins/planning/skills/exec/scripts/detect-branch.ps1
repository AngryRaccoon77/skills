# detect the default branch name of the current repository (Codex port)
# outputs the branch name to stdout; avoids network calls when possible
# VCS-aware: dispatches to git or hg based on detect-vcs.ps1

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$vcs = & (Join-Path $scriptDir 'detect-vcs.ps1')
if ($LASTEXITCODE -ne 0) { exit 1 }

function Get-DefaultBranchGit {
    # 1. check cached remote HEAD (local, fast)
    $branch = ''
    $ref = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $ref) {
        $branch = ($ref -replace '^refs/remotes/origin/', '')
    }

    # 2. check for common default branch names locally
    if ([string]::IsNullOrEmpty($branch)) {
        foreach ($candidate in @('main', 'master', 'trunk', 'develop')) {
            git show-ref --verify --quiet "refs/heads/$candidate" *> $null
            if ($LASTEXITCODE -eq 0) {
                $branch = $candidate
                break
            }
        }
    }

    # 3. last resort: ask remote (may block if network is unreachable)
    if ([string]::IsNullOrEmpty($branch)) {
        $remoteShow = git remote show origin 2>$null
        if ($LASTEXITCODE -eq 0) {
            $headLine = $remoteShow | Select-String 'HEAD branch'
            if ($headLine) {
                $branch = (($headLine.ToString()) -replace '.*:\s*', '')
            }
        }
    }

    # 4. fallback
    if ([string]::IsNullOrEmpty($branch)) {
        $branch = 'main'
    }

    return $branch
}

function Get-DefaultBranchHg {
    # probe common default-branch remote-tracking refs first — modern Mercurial
    # workflows expose the upstream default as remote/<name>. present(remote/<name>)
    # returns empty instead of aborting when the revset is absent.
    foreach ($candidate in @('master', 'main', 'trunk')) {
        $node = hg log -r "present(remote/$candidate)" --template '{node}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $node) {
            return "remote/$candidate"
        }
    }
    # vanilla-hg fallback: the traditional named branch
    return 'default'
}

switch ($vcs) {
    'git' { Write-Output (Get-DefaultBranchGit) }
    'hg'  { Write-Output (Get-DefaultBranchHg) }
    default {
        Write-Error "unsupported VCS: $vcs"
        exit 1
    }
}
