# initialize the progress file with a header (Codex port)
# usage: init-progress.ps1 <progress-file> <plan-path> <branch-name>

$ErrorActionPreference = 'Stop'

if ($args.Count -lt 3) {
    Write-Error 'usage: init-progress.ps1 <progress-file> <plan-path> <branch-name>'
    exit 1
}

$file = $args[0]
$plan = $args[1]
$branch = $args[2]

$header = @"
# progress
Plan: $plan
Branch: $branch
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
---
"@

Set-Content -LiteralPath $file -Value $header

Write-Output $file
