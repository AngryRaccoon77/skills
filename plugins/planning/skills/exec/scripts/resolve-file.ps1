# resolve a file through the three-layer override chain (Codex port)
# usage: resolve-file.ps1 <relative-path> [user-override-dir]
# e.g.:  resolve-file.ps1 prompts/task.md
#
# checks in order:
#   1. <cwd>/.codex/exec-plan/<path>            (project override)
#   2. <user-override-dir>/<path>             (user override; defaults to $HOME/.codex/rules/exec-plan)
#   3. bundled default (derived from script location: ../references/<path>)
#
# outputs the file content to stdout

$ErrorActionPreference = 'Stop'

$path = $args[0]
if ([string]::IsNullOrWhiteSpace($path)) {
    Write-Error 'usage: resolve-file.ps1 <relative-path> [user-override-dir]'
    exit 1
}

$userDir = if ($args.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($args[1])) {
    $args[1]
} else {
    Join-Path $HOME (Join-Path '.codex\rules' 'exec-plan')
}

# derive skill root from script location: script is at <skill-root>/scripts/resolve-file.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir

$candidates = @(
    (Join-Path (Get-Location) (Join-Path '.codex\exec-plan' $path)),
    (Join-Path $userDir $path),
    (Join-Path $skillRoot (Join-Path 'references' $path))
)

foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        Get-Content -LiteralPath $candidate -Raw
        exit 0
    }
}

Write-Error "file not found in override chain: $path"
exit 1
