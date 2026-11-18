# calculate new semantic version from last tag (Codex port)
# usage: calc-version.ps1 <release_type>
# release_type: major, minor, hotfix
# outputs: new version (e.g., v1.2.3)

$ErrorActionPreference = 'Stop'

$releaseType = $args[0]

if ([string]::IsNullOrWhiteSpace($releaseType)) {
    Write-Error 'release type required (major, minor, hotfix)'
    exit 1
}

# fetch tags from remote to ensure we have the latest
git fetch origin --tags 2>$null

# get last tag
$lastTag = git describe --tags --abbrev=0 --match 'v*' 2>$null
if ($LASTEXITCODE -ne 0) { $lastTag = '' }

# first release defaults
if ([string]::IsNullOrEmpty($lastTag)) {
    switch ($releaseType) {
        'major'  { Write-Output 'v1.0.0'; exit 0 }
        'minor'  { Write-Output 'v0.1.0'; exit 0 }
        'hotfix' { Write-Output 'v0.0.1'; exit 0 }
        default  {
            Write-Error "invalid type: $releaseType"
            exit 1
        }
    }
}

# parse version (strip 'v' prefix and any pre-release suffix)
$version = $lastTag -replace '^v', ''
$baseVersion = ($version -split '-')[0]
$parts = $baseVersion -split '\.'
if ($parts.Count -lt 3 -or $parts[0] -notmatch '^\d+$' -or $parts[1] -notmatch '^\d+$' -or $parts[2] -notmatch '^\d+$') {
    Write-Error "cannot parse version from $lastTag"
    exit 1
}
$major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]

# calculate new version
switch ($releaseType) {
    'major'  { Write-Output "v$($major + 1).0.0" }
    'minor'  { Write-Output "v${major}.$($minor + 1).0" }
    'hotfix' { Write-Output "v${major}.${minor}.$($patch + 1)" }
    default  {
        Write-Error "invalid type: $releaseType"
        exit 1
    }
}
