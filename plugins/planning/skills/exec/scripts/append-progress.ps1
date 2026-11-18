# append to the progress file with timestamp (Codex port)
# usage: append-progress.ps1 <progress-file> [message]
# if message is provided, appends single timestamped line
# if no message, reads stdin and appends all lines (for multi-line content)

$ErrorActionPreference = 'Stop'

if ($args.Count -lt 1) {
    Write-Error 'usage: append-progress.ps1 <file> [message]'
    exit 1
}

$file = $args[0]

if ($args.Count -gt 1) {
    # single line with timestamp
    $msg = ($args[1..($args.Count - 1)] -join ' ')
    Add-Content -LiteralPath $file -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
} else {
    # multi-line from stdin
    [Console]::In.ReadToEnd() | Add-Content -LiteralPath $file
}

exit 0
