# detect the VCS of the current working directory (Codex port)
# outputs "git" or "hg" on stdout; exits 1 if neither
# precedence: git first, hg second; if both colocated, git wins

$ErrorActionPreference = 'Stop'

git rev-parse --git-dir *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Output 'git'
    exit 0
}

$hgCmd = Get-Command hg -ErrorAction SilentlyContinue
if ($null -ne $hgCmd) {
    hg root *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Output 'hg'
        exit 0
    }
}

Write-Error 'not a git or mercurial repository'
exit 1
