# resolve custom rules file through the two-layer override chain (Codex port)
# usage: resolve-rules.ps1 <filename>
# e.g.:  resolve-rules.ps1 brainstorm-rules.md
#
# checks in order (first-found-wins, not merged):
#   1. <cwd>/.codex/rules/<filename>   (project override)
#   2. $HOME/.codex/rules/<filename>   (user override)
#
# outputs file content to stdout if found, empty output if not.
# always exits 0 unless the file cannot be read at all.
param(
    [Parameter(Position = 0)]
    [string]$FileName
)

if ([string]::IsNullOrWhiteSpace($FileName)) {
    exit 0
}

$candidates = @(
    (Join-Path (Get-Location) (Join-Path '.codex\rules' $FileName)),
    (Join-Path $HOME (Join-Path '.codex\rules' $FileName))
)

foreach ($path in $candidates) {
    if ((Test-Path -LiteralPath $path -PathType Leaf) -and ((Get-Item -LiteralPath $path).Length -gt 0)) {
        Get-Content -LiteralPath $path -Raw
        exit 0
    }
}

exit 0
