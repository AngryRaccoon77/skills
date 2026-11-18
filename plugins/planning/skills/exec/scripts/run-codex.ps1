# run codex review and return output (Codex port)
# usage: run-codex.ps1 "<prompt>"
# outputs codex response to stdout
# VCS-aware: in hg repos, adds --skip-git-repo-check so codex doesn't refuse

$ErrorActionPreference = 'Stop'

$prompt = $args[0]
if ([string]::IsNullOrWhiteSpace($prompt)) {
    Write-Error "usage: run-codex.ps1 '<prompt>'"
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$vcs = & (Join-Path $scriptDir 'detect-vcs.ps1')
if ($LASTEXITCODE -ne 0) { exit 1 }

# build args so the hg-specific flag sits right after 'exec' (before --sandbox)
$codexArgs = [System.Collections.Generic.List[string]]::new()
$codexArgs.Add('exec')
if ($vcs -eq 'hg') { $codexArgs.Add('--skip-git-repo-check') }
$codexArgs.Add('--sandbox')
$codexArgs.Add('read-only')

# -c overrides switch provider routing in a way some corporate codex proxies /
# wrappers reject (e.g. "Error: Model provider 'responses' not found").
# Set CODEX_NO_OVERRIDES=1 to skip the overrides and fall through to the
# proxy's defaults. Only the literal value `1` activates suppression — any
# other value (including `0`, `false`, empty) keeps the overrides on.
if ($env:CODEX_NO_OVERRIDES -ne '1') {
    if ($env:CODEX_MODEL) {
        $codexArgs.Add('-c')
        $codexArgs.Add("model=$env:CODEX_MODEL")
    }
    $codexArgs.Add('-c')
    $codexArgs.Add('model_reasoning_effort=xhigh')
}

$codexArgs.Add($prompt)

$codexArgsArray = $codexArgs.ToArray()

# Empty piped stdin closes immediately: codex exec reads stdin to append a
# <stdin> block even when a prompt arg is given, so an inherited open pipe
# would block read_to_end forever. Empty stdin is ignored when a prompt arg
# is present.
'' | codex @codexArgsArray
exit $LASTEXITCODE
