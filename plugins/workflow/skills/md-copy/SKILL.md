---
name: md-copy
description: "Format final answer as markdown and copy to clipboard. Use when user says \"copy as markdown\", \"md copy\", \"copy formatted\", \"clipboard\", or wants the session's final answer formatted and copied."
---

# Markdown Copy

For Codex, use the tools available in the current client. Ask a needed question in chat if the question tool is unavailable.

Extract the final answer from this session, convert it to proper markdown format, and copy to clipboard.

## Formatting Rules

1. **No heading elements** (`#`, `##`, etc.) — use **bold** for section titles instead
2. Convert any ASCII tables to proper markdown tables
3. Use *italic* for emphasis and minor notes
4. Preserve code blocks with proper language tags
5. Keep bullet lists and numbered lists
6. Remove any leading spaces or bullet headers (bullet-style)
7. Give the content a nice descriptive title (as bold text, not heading)

## Workflow

1. Identify the final answer/response in this session
2. Format it according to the rules above
3. Write formatted text to a timestamped temp file (PowerShell, Windows-native):
```powershell
$tmpfile = Join-Path $env:TEMP ("codex-md-copy-{0}.txt" -f ([DateTimeOffset]::Now.ToUnixTimeSeconds()))
@'
<formatted content>
'@ | Set-Content -LiteralPath $tmpfile -Encoding UTF8
```
4. Copy to clipboard and remove temp file:
```powershell
Get-Content -LiteralPath $tmpfile -Raw | Set-Clipboard
Remove-Item -LiteralPath $tmpfile -Force
```
Cross-platform variants when not on Windows: macOS `pbcopy < $tmpfile`; Linux `xclip -selection clipboard < $tmpfile` or `xsel --clipboard --input < $tmpfile`.

5. Report success with character count.
