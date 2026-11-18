---
name: git-review
description: "Interactive git diff annotation review. Generates a cleaned-up diff file, the user annotates it directly, and the model addresses feedback in a loop. Activates on \"git review\", \"review changes\", \"review my changes\", \"annotate changes\", \"interactive review\"."
---

# Git Review

For Codex, use the tools available in the current client. Ask a needed question in chat if the question tool is unavailable.

Interactive annotation-based code review with a file-based annotation loop.

Resolve bundled relative paths from the directory that contains this SKILL.md.

## Activation Triggers

- "git review", "review changes", "review my changes"
- "annotate changes", "interactive review"
- "review diff", "annotate diff"

## How It Works

1. Model generates a cleaned-up diff file (friendly headers, no technical noise) in the workspace
2. User opens that file in any editor/GUI view and adds annotations (comments, change requests) directly in it, then saves
3. User tells the model the annotations are ready; the model reads the annotated file back
4. Model reads annotations, plans and fixes code in the real repo
5. Model regenerates a fresh diff (reflecting fixes), user annotates again if needed
6. Loop until the user reviews a round without adding annotations

## Workflow

### Step 1: Generate the review diff

Prepare `.codex/review/` in the project root (create as needed) and write the diff to `.codex/review/<timestamp>.diff`. Decide the diff range:

- **Explicit ref given**: `git diff <ref>` (branch, tag, commit, `HEAD~3`)
- **No arguments**: auto-detect — if there are uncommitted changes (`git status --porcelain` non-empty), use `git diff HEAD` for tracked work plus a listing of untracked files; otherwise diff against the default branch:
  1. `git symbolic-ref refs/remotes/origin/HEAD` (strip the prefix)
  2. else first existing local branch among `main`, `master`, `trunk`, `develop`
  3. else fall back to `main`

Clean up the output so it is pleasant to annotate:

```powershell
# readable per-file diffs without noise; add --stat header at top
git diff --stat <range>
git diff <range> -- . ':(exclude)*.lock'
```

Format each file section with a friendly header:

```
=== path/to/file.go ===
<diff hunk content>
```

Skip lockfiles, generated files, and binaries (list them at the end under "not shown"). Keep the diff minimal-context (`-U3` default is fine).

### Step 2: Ask the user to annotate

Tell the user:
> Review file ready: `.codex/review/<timestamp>.diff`. Open it in your editor, add comments or change requests on the lines you care about (prefix with `#` or `>>`, or just write plain text next to the code), save the file, then tell me when done.

### Step 3: Process annotations

When the user responds, re-read the review file. Annotations appear as added lines within the diff context:

- **Lines starting with `#` or `>>`, or free text between hunks**: user's comments/change requests
- **Modified context**: user edited the snippet to show desired change

Each annotation is in context — the surrounding `===` file headers show which file and code area it refers to. If the file is unchanged from what you generated, the review is complete (see Step 6).

### Step 4: Plan changes

Enter plan mode to analyze annotations and design the fix approach:
- list each annotation and which file/code area it refers to
- describe the planned changes for each annotation
- get user approval before modifying any code

### Step 5: Address annotations

After plan approval, fix the actual source code in the real repository.
Each annotation is a directive — treat it as a code review comment that must be addressed.

Then regenerate a fresh review diff into a NEW timestamped file reflecting the fixes, and go back to Step 2.

### Step 6: Done

When a review round comes back without new annotations, the review is complete. Inform the user and offer to clean up old `.codex/review/*.diff` files.

## Example Session

```
User: "review my changes"
→ generate .codex/review/20260417-101500.diff (uncommitted changes detected)
→ user adds "this should validate input" next to a handler, saves, says done
→ enter plan mode: "annotation requests input validation in handler.go, plan: add validate() call"
→ user approves plan
→ model adds input validation to the handler
→ generate .codex/review/20260417-102200.diff (validation now visible)
→ user reviews, no new annotations, says ok
→ "review complete, all annotations addressed"
```

## Requirements

- git (no terminal overlay, no `$EDITOR`, no tmux/kitty/wezterm/agterm needed)
