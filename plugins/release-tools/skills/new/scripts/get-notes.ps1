# generate release notes from PRs/MRs and commits (Codex port)
# usage: get-notes.ps1 <platform>
# platform: github, gitlab, or gitea
# outputs: release notes grouped by type (features, improvements, fixes)
#
# port note: the upstream bash implementation shaped forge JSON with jq; this port
# uses PowerShell's ConvertFrom-Json instead, keeping the same semantics —
# pagination until a short page, UTC string compare of merge time vs tag creatordate,
# hard failure when the forge CLI fails or is missing.

$ErrorActionPreference = 'Stop'

function Write-Fail {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

$platform = $args[0]

if ([string]::IsNullOrWhiteSpace($platform)) {
    Write-Fail 'platform required (github, gitlab, gitea)'
}

if ($platform -notin @('github', 'gitlab', 'gitea')) {
    Write-Fail "unknown platform: $platform (expected github, gitlab or gitea)"
}

# fetch tags from remote to ensure we have the latest
git fetch origin --tags 2>$null

# get last tag
$lastTag = git describe --tags --abbrev=0 --match 'v*' 2>$null
if ($LASTEXITCODE -ne 0) { $lastTag = '' }

# tag date in UTC (empty if no tag). Forge APIs report merge times in UTC with a 'Z'
# suffix and we compare timestamps as strings, so the tag date must be rendered the
# same way. creatordate is the tag's own time (tagger time for annotated tags,
# committer time for lightweight ones).
$tagDate = ''
if (-not [string]::IsNullOrEmpty($lastTag)) {
    $env:TZ = 'UTC'
    try {
        $tagDate = git for-each-ref --format '%(creatordate:format-local:%Y-%m-%dT%H:%M:%SZ)' "refs/tags/$lastTag" 2>$null
        if ($LASTEXITCODE -ne 0) { $tagDate = '' }
        if ([string]::IsNullOrEmpty($tagDate)) {
            $tagDate = git log -1 --date=format-local:'%Y-%m-%dT%H:%M:%SZ' --format=%cd $lastTag 2>$null
            if ($LASTEXITCODE -ne 0) { $tagDate = '' }
        }
    } finally {
        Remove-Item Env:TZ -ErrorAction SilentlyContinue
    }
}

function Get-ConventionalClean {
    param([string]$Description)
    return ($Description -replace '^(feat|fix|refactor|perf|chore|docs|style|build|ci|test)(\([^)]*\))?\s*:\s*', '')
}

$features = [System.Collections.Generic.List[string]]::new()
$improvements = [System.Collections.Generic.List[string]]::new()
$fixes = [System.Collections.Generic.List[string]]::new()
$other = [System.Collections.Generic.List[string]]::new()

function Add-Entry {
    param([string]$Description, [string]$Suffix)
    $lower = $Description.ToLowerInvariant()
    $clean = Get-ConventionalClean $Description
    $entry = "- $clean $Suffix"
    if ($lower.StartsWith('feat')) { $features.Add($entry) }
    elseif ($lower.StartsWith('fix')) { $fixes.Add($entry) }
    elseif ($lower -match '^(refactor|perf|chore|docs|style|build|ci|test)') { $improvements.Add($entry) }
    else { $other.Add($entry) }
}

function Invoke-ForgeChecked {
    # runs a forge CLI and aborts on failure so a missing/unauthenticated/
    # rate-limited CLI never reads as "this release has no PRs"
    param([string]$ExeName, [string[]]$CliArgs)
    $exe = Get-Command $ExeName -ErrorAction SilentlyContinue
    if ($null -eq $exe) {
        Write-Fail "$ExeName failed: not found on PATH"
    }
    $out = & $ExeName @CliArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "$ExeName failed: $(($out | Out-String).Trim())"
    }
    return $out
}

# collect PRs/MRs
if ($platform -eq 'github') {
    # gh pr list has no page flag. grow its total limit until the returned array is
    # shorter than requested; the final response then contains every merged PR.
    $limit = 50
    while ($true) {
        $raw = Invoke-ForgeChecked 'gh' @('pr', 'list', '--state', 'merged', '--limit', "$limit", '--json', 'number,title,mergedAt,author')
        $prs = $raw | Out-String | ConvertFrom-Json
        if ($prs.Count -lt $limit) { break }
        $limit = $limit * 2
    }
    foreach ($pr in $prs) {
        if ($tagDate -and $pr.mergedAt -and ([string]$pr.mergedAt -le $tagDate)) { continue }
        Add-Entry -Description $pr.title -Suffix "#$($pr.number) @$($pr.author.login)"
    }
} elseif ($platform -eq 'gitlab') {
    # glab reads one page at a time; combine pages until the first short response.
    $perPage = 100
    $page = 1
    $allMrs = [System.Collections.Generic.List[object]]::new()
    while ($true) {
        $raw = Invoke-ForgeChecked 'glab' @('mr', 'list', '--merged', '-F', 'json', '--page', "$page", '--per-page', "$perPage")
        $pageMrs = $raw | Out-String | ConvertFrom-Json
        foreach ($mr in $pageMrs) { $allMrs.Add($mr) }
        if (@($pageMrs).Count -lt $perPage) { break }
        $page = $page + 1
    }
    foreach ($mr in $allMrs) {
        if ($tagDate -and $mr.merged_at -and ([string]$mr.merged_at -le $tagDate)) { continue }
        Add-Entry -Description $mr.title -Suffix "!$($mr.iid) @$($mr.author.username)"
    }
} elseif ($platform -eq 'gitea') {
    # `tea pr list` cannot supply merged-PR metadata. warn and fall through to
    # commit-derived notes -- aborting here would make every gitea release impossible.
    Write-Host 'warning: gitea PR metadata is unavailable, notes are commit-derived only' -ForegroundColor Yellow
}

# collect commits (exclude merge commits)
if (-not [string]::IsNullOrEmpty($lastTag)) {
    $log = git log "$lastTag..HEAD" --oneline --no-merges --pretty='%h%x09%s'
} else {
    $log = git log --oneline --no-merges --pretty='%h%x09%s' -20
}
foreach ($line in $log) {
    $tab = $line.IndexOf("`t")
    if ($tab -lt 0) { continue }
    $hash = $line.Substring(0, $tab)
    $msg = $line.Substring($tab + 1)
    Add-Entry -Description $msg -Suffix $hash
}

# build output
$sections = @()
foreach ($pair in @(@('New Features', $features), @('Improvements', $improvements), @('Bug Fixes', $fixes), @('Other', $other))) {
    if ($pair[1].Count -gt 0) {
        $sections += "**$($pair[0])**`n$($pair[1] -join "`n")"
    }
}

Write-Output ($sections -join "`n`n")
