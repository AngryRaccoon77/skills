# detect GitHub vs GitLab vs Gitea from git remote (Codex port)
# outputs: github, gitlab or gitea on stdout, errors on stderr

$ErrorActionPreference = 'Stop'

git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Error 'not a git repository'
    exit 1
}

# keep going when origin is missing so the check below reports it
$remoteUrl = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) { $remoteUrl = '' }

if ([string]::IsNullOrEmpty($remoteUrl)) {
    Write-Error 'no origin remote configured'
    exit 1
}

if ($remoteUrl -match '(?i)github\.com') {
    Write-Output 'github'
} elseif ($remoteUrl -match '(?i)gitlab\.') {
    Write-Output 'gitlab'
} elseif ($remoteUrl -match '(?i)gitea\.') {
    Write-Output 'gitea'
} elseif ((Get-Command glab -ErrorAction SilentlyContinue) -and (glab repo view *> $null) -and ($LASTEXITCODE -eq 0)) {
    Write-Output 'gitlab'
} else {
    Write-Error "unknown platform for $remoteUrl"
    exit 1
}
