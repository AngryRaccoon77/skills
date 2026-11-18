# stage files and commit with a message (Codex port)
# usage: stage-and-commit.ps1 <message> <file1> [file2 ...]
# VCS-aware: dispatches to git or hg based on detect-vcs.ps1

$ErrorActionPreference = 'Stop'

if ($args.Count -lt 2) {
    Write-Error 'usage: stage-and-commit.ps1 <message> <file1> [file2 ...]'
    exit 1
}

$msg = $args[0]
$files = $args[1..($args.Count - 1)]

# an empty path must be rejected here: as a git pathspec it matches everything under
# the current directory, so it would silently commit the whole tree instead of failing
foreach ($f in $files) {
    if ([string]::IsNullOrWhiteSpace($f)) {
        Write-Error 'empty file argument'
        exit 1
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$vcs = & (Join-Path $scriptDir 'detect-vcs.ps1')
if ($LASTEXITCODE -ne 0) { exit 1 }

switch ($vcs) {
    'git' {
        # every name is passed as a literal pathspec so one holding '*', '?' or '[...]'
        # matches itself rather than something else.
        git add -- @($files | ForEach-Object { ":(literal)$_" })
        if ($LASTEXITCODE -ne 0) { throw 'git add failed' }

        git commit -m $msg -- @($files | ForEach-Object { ":(literal)$_" })
        if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }

        # a path-scoped commit runs hooks against a temporary index, so nothing a
        # pre-commit hook stages reaches the real index. reconcile every path the
        # commit actually recorded; anything staged but not committed is left alone.
        $committed = git diff-tree --no-commit-id --name-only -r --root HEAD
        if ($LASTEXITCODE -eq 0 -and $committed) {
            git reset -q -- @($committed | ForEach-Object { ":(top,literal)$_" })
        }
    }
    'hg' {
        # -A marks untracked files as added and missing files as removed within the
        # commit selection — parity with the path-scoped git commit above.
        hg commit -A -m $msg -- @files
        if ($LASTEXITCODE -ne 0) { throw 'hg commit failed' }
    }
    default {
        Write-Error "unsupported VCS: $vcs"
        exit 1
    }
}

exit 0
