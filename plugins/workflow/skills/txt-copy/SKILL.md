---
name: txt-copy
description: "Copy generated text content to clipboard. Use when user asks to \"copy this\", \"copy to clipboard\", \"save to clipboard\", or after creating emails, messages, letters, or other text content that needs to be shared."
---

# Copy Text to Clipboard

For Codex, use the tools available in the current client. Ask a needed question in chat if the question tool is unavailable.

Copy generated text content to clipboard via a timestamped temp file.

## Activation Triggers

- "copy this", "copy to clipboard", "save to clipboard"
- "copy the email", "copy the message", "copy the letter"
- After generating text content when user indicates they want to use it
- "I need to paste this", "put it in clipboard"

## Workflow

1. Identify the text content to copy (from recent generation or user-specified)

2. Write to timestamped temp file (PowerShell, Windows-native):
```powershell
$tmpfile = Join-Path $env:TEMP ("codex-txt-copy-{0}.txt" -f ([DateTimeOffset]::Now.ToUnixTimeSeconds()))
@'
<content here>
'@ | Set-Content -LiteralPath $tmpfile -Encoding UTF8
```

3. Copy to clipboard and remove temp file:
```powershell
Get-Content -LiteralPath $tmpfile -Raw | Set-Clipboard
Remove-Item -LiteralPath $tmpfile -Force
```
Cross-platform variants when not on Windows: macOS `pbcopy < $tmpfile`; Linux `xclip -selection clipboard < $tmpfile` or `xsel --clipboard --input < $tmpfile`.

4. Confirm to user: "Copied to clipboard (N characters)"

## Notes

- Temp file uses a Unix-seconds timestamp to avoid collisions across invocations
- Temp file is removed after clipboard copy
- If clipboard access fails in a headless context, report the failure honestly instead of claiming success
