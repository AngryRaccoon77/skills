---
name: exec
description: "Execute plan tasks sequentially using isolated subagents with multi-phase review. Use when user says 'exec', 'execute plan', 'run plan', or wants to implement a plan file task by task autonomously."
---

# planning-exec

For Codex, use the tools available in the current client. For questions, use the Codex question tool when available. Adapt the examples to its input fields or ask in chat. Use Codex subagents only when the current instructions permit them; otherwise do the work in the main session. Follow the user's authorization for commits, publishing and writes.

Execute plan file tasks sequentially, each in an isolated subagent.

Use the absolute directory containing this SKILL.md as EXEC_SKILL_DIR. Resolve bundled scripts and references from that directory. Pass absolute paths to subagents and shell commands.

## Arguments

- Use the supplied plan path, or resolve it from docs/plans/. Defaults: one retry per task, five iterations per local review phase and ten independent review iterations.

## File Resolution

ALWAYS use the resolve script to read prompt and agent files. NEVER construct the override chain manually:

```powershell
pwsh -File <EXEC_SKILL_DIR>/scripts/resolve-file.ps1 prompts/task.md
pwsh -File <EXEC_SKILL_DIR>/scripts/resolve-file.ps1 agents/quality.txt
```

The script checks project overrides (`<cwd>/.codex/exec-plan/<path>`), user overrides (`$HOME/.codex/rules/exec-plan/<path>`), and bundled defaults automatically. When a prompt template asks you to pass `PLUGIN_DATA_DIR`, use `$HOME/.codex/rules/exec-plan` resolved to an absolute path.

### Placeholder Substitution

After reading a prompt file, replace ALL placeholders with actual values before passing it to a subagent. Subagents run in fresh contexts without your session state.

Always substitute: `PLAN_FILE_PATH`, `PROGRESS_FILE_PATH`, `DEFAULT_BRANCH`, `EXEC_SKILL_DIR` (absolute path of this skill directory), `RESOLVE_SCRIPT` (absolute path to `<EXEC_SKILL_DIR>/scripts/resolve-file.ps1`), `PLUGIN_DATA_DIR` (absolute `$HOME/.codex/rules/exec-plan`), `USER_RULES` (resolved custom rules content from the rules loading step, or empty string if no rules found), and phase-specific values (`FINDINGS_LIST`, `REVIEW_PHASE`, `DIFF_COMMAND`).

## Custom Rules Loading

Before starting execution, run this command via the shell tool from the project working directory to check for user-provided custom rules:

```powershell
pwsh -File <EXEC_SKILL_DIR>/scripts/resolve-rules.ps1 planning-rules.md
```

If the output is non-empty, store it as the resolved custom rules content. When substituting `USER_RULES` in task prompts, wrap the content with a label so the subagent understands it: use `ADDITIONAL CUSTOM RULES:\n<content>` as the substitution. If the output is empty, substitute an empty string for `USER_RULES`. See the planning-make skill's `references/custom-rules.md` for full documentation on the rules mechanism.

## Process

### Step 1. Resolve plan file

If the arguments contain a file path, use it. Otherwise, list `.md` files in the `plans_dir` directory (default: `docs/plans/`), excluding `completed/`. If exactly one plan is found, use it automatically. If multiple are found, ask the user to pick one using `request_user_input`.

Read the plan file. Count total Task sections (`### Task N:` or `### Iteration N:`) to know the scope.

Determine the default branch: `pwsh -File <EXEC_SKILL_DIR>/scripts/detect-branch.ps1`


### Step 2. Select a checkout

Keep using an existing isolated worktree if it is suitable. For a new task on the default branch, create a Codex worktree or use git worktree add with an available path. Preserve any changes in the user's checkout. Use the selected checkout as the working directory for every task, command and reviewer. If the plan requires uncommitted changes from another checkout, resolve that dependency before creating the worktree.

### Step 3. Create task list

Track tasks with update_plan when available, or with the plan checkboxes. Create one task per plan Task section plus review phases:

For each `### Task N:` section in the plan:
- one todo: `"Executing task N: <title>"`

Then add review todos:
- `"Review phase 1: comprehensive"` (5 parallel review agents + fixer)
- `"Review phase 2: code smells"` (smells agent + fixer)
- `"Review phase 3: codex external"` (adversarial codex review loop)
- `"Review phase 4: critical only"` (2 review agents + fixer)
- `"Finalize"` (verify all changes)
- `"Stats summary"` (aggregate duration/git stats)

Update as you go: mark each todo `in_progress` when starting and `completed` when done (do not batch).

### Step 4. Confirm the branch

If Step 2 selected or created a worktree on a task branch, keep its branch and go to Step 5.

Otherwise (in-place mode), **MANDATORY**: run the script below. Do NOT create the branch manually — the script strips the date prefix from the plan filename (e.g., `20260329-feature-name.md` → branch `feature-name`):

```
pwsh -File <EXEC_SKILL_DIR>/scripts/create-branch.ps1 <plan-file-path>
```

The script creates a feature branch if currently on main/master, or stays on the current branch if already on a feature branch. Capture and use the branch name it outputs.

### Step 5. Initialize progress file

Initialize the progress file (use the OS temp dir instead of `/tmp` on Windows): `pwsh -File <EXEC_SKILL_DIR>/scripts/init-progress.ps1 "$env:TEMP/progress-<plan-name>.txt" <plan-file-path> <branch-name>` (derive `<plan-name>` from the plan file stem, e.g., `fix-issues.md` → `progress-fix-issues`). The script creates the file with a header. Report the full progress file path to the user.

IMPORTANT: Always use `<EXEC_SKILL_DIR>/scripts/append-progress.ps1` to write to the progress file after initialization. Never write directly.

### Step 6. Task loop

Repeat until no `[ ]` checkboxes remain in any Task section:

1. **Re-read the plan file** (subagents modify it each iteration)
2. **Find the first Task section** (`### Task N:` or `### Iteration N:`) that still has `[ ]` checkboxes
3. **If none found** — all tasks complete, go to step 7
4. **Announce the task to the user** — before spawning the subagent, output a visible summary:
   - Task number and title (from the `### Task N:` header)
   - List all `[ ]` checkbox items in that task section
   - Example output:
     ```
     --- Task 1: Fix error handling ---
     - [ ] Handle the error from os.ReadFile
     - [ ] Either log and exit or handle gracefully
     ```
5. **Spawn ONE subagent** with the available Codex subagent tool with the task prompt from `prompts/task.md` (resolved through the override chain), with all placeholders substituted as described above (including `USER_RULES`)
6. **After the subagent returns**, re-read the plan file and check if that task's checkboxes are now `[x]`
   - If yes — task succeeded, continue loop
   - If no — **retry** with a fresh subagent for the same task up to `task_retries` times (default: 1). If all retries fail, stop and report failure to user
7. **Report to user**: "Task N completed" (one line). The task subagent logs details to the progress file.

CRITICAL: Spawn exactly ONE task subagent per iteration and WAIT for it to return before starting the next. NEVER batch-spawn multiple task subagents in a single message. Plan tasks are ordered and interdependent — later tasks build on the files earlier tasks create, and every task subagent edits the same plan-file checkboxes and overlapping source files, so running them in parallel corrupts the plan and the working tree. The "launch several calls in a single message for parallel execution" instruction applies ONLY to the review phases (steps 7 and 10), never to this task loop.

CRITICAL: Do NOT stop the loop based on subagent return text. The ONLY condition to stop is: no `[ ]` checkboxes remain in any Task section (`### Task N:` or `### Iteration N:`). Always re-read the plan file to check.

If an agent is unavailable, execute and verify each task in the main session. When using agents, give a retry the preceding diagnostics and verify the result yourself.

Maximum iterations safety limit: 50. If reached, stop and report to user.

### Step 7. Review phase 1 — comprehensive then critical re-check

After all tasks complete, run a comprehensive code review on iteration 1, then narrow to critical-only re-checks on subsequent iterations to verify the fixer's work without re-running the full heavy sweep.

Report to user: "--- Review phase 1: comprehensive ---"

Loop up to `review_iterations` times (default: 5). Track the current iteration number:

1. **Read review.md as a playbook (NOT as a subagent prompt)** — resolve `prompts/review.md` through the override chain and read it in this main session. It tells YOU (the orchestrator) which specialist agents to fan out for the current `REVIEW_PHASE`. Substitute `DEFAULT_BRANCH`, `PLAN_FILE_PATH`, `PROGRESS_FILE_PATH`, `EXEC_SKILL_DIR`, and `REVIEW_PHASE` in the resolved content. Then follow the playbook FROM THIS SESSION: start the specified Codex subagents before waiting for parallel execution. Subagents cannot spawn other subagents, so the fanout MUST be initiated from the main orchestrator.
   - **Iteration 1**: set `REVIEW_PHASE` to `comprehensive`. Per the playbook, launch 5 parallel review agents (quality, implementation, testing, simplification, documentation).
   - **Iteration 2 and later**: set `REVIEW_PHASE` to `critical`. Per the playbook, launch 2 parallel review agents (quality, implementation) focused on critical/major issues only. Before this iteration, report to user: "--- Review phase 1: critical re-check (iteration N) ---"

2. **Collect findings** — collect findings from ALL launched review agents. Pass the COMPLETE output (not a summary) to the fixer. Do NOT summarize, filter, or dismiss any findings. ALL findings are actionable. Report to user with a short list of findings. Log to progress file:
   `pwsh -File <EXEC_SKILL_DIR>/scripts/append-progress.ps1 <progress-file> "review phase 1: findings"`
   Then pipe the findings text into the same script (no message argument) to append multi-line content.

3. **If ALL agents reported zero issues** → report "Review phase 1: clean" and proceed to the next phase.

4. **Spawn a fixer agent** — resolve `prompts/fixer.md` through the override chain. Launch it as a `subagent` with the FULL unedited review output substituted as FINDINGS_LIST — the fixer decides what's real, not you.

5. **After fixer returns** → show the "FIXES:" section to the user. Report "Review phase 1: iteration N fixes applied". Loop back to step 1.

If `review_iterations` reached with issues still found, report "Review phase 1: max iterations reached, moving on" and continue.

### Step 8. Review phase 2 — code smells

Report to user: "--- Review phase 2: code smells analysis ---"

Run once (no loop):

1. **Spawn a smells agent** — resolve `agents/smells.txt` through the override chain. Launch one `subagent` with the resolved agent prompt.

2. **Collect findings** — after the agent returns, report to user with a compact list of findings (one line per finding). Log findings to progress file via append-progress.ps1 (header line first, then piped multi-line content).

3. **If no issues found** → report "Smells analysis: clean" and proceed to the next phase.

4. **Spawn a fixer agent** — resolve `prompts/fixer.md` through the override chain. Launch as a `subagent` with the FULL smells output as FINDINGS_LIST.

5. **After fixer returns** → report fixes to user. Proceed to the next phase.

### Step 9. Review phase 3 — independent Codex review

In a Git checkout, resolve prompts/codex-review.md with the same overrides as other review prompts. Fill in the plan path, base branch and diff command. Run scripts/run-codex.ps1 with the complete prompt as one argument. Use an asynchronous shell session when one is available and wait for the result.

Judge the reviewer by stdout. Preserve stderr for diagnostics. A missing reviewer, timeout, failed command or empty output does not establish a clean review. Verify findings against the code, fix confirmed issues and repeat the review while blocking findings remain, up to ten iterations. Explain any unresolved issue. Skip this Git-specific review on Mercurial unless the project supplies a compatible review procedure.

### Step 10. Review phase 4 — critical only

Report to user: "--- Review phase 4: critical/major only (single pass) ---"

Same structure as step 7 but with `REVIEW_PHASE` set to `critical`. Resolve `prompts/review.md` and follow its playbook FROM THIS MAIN SESSION — launch 2 parallel review agents (quality, implementation) focusing on critical/major issues only. Subagents cannot spawn other subagents, so the fanout MUST be initiated from the main orchestrator. Same fixer flow — pass findings to fixer, show FIXES to user.

### Step 11. Finalize

Run the plan's validation commands and review the final diff for unrelated changes. Make commits, rewrite history or push only as authorized by the user and consistent with project rules. Keep the checkout available for review.

### Step 12. Stats summary

Spawn one `subagent` with the prompt from `prompts/stats.md`. Replace `DEFAULT_BRANCH` and `PROGRESS_FILE_PATH` in the resolved content.


Show the stats agent's full markdown output to the user verbatim. Do NOT summarize it further — the agent already produces a tight summary.

This step is best-effort — if the stats agent fails, report the failure but do not block completion.

### Step 13. Completion

When stats summary is done (or skipped on failure):
- **Report autonomous decisions and deviations to the user.** The run had no human to answer questions, so subagents decided judgment calls themselves and logged them. Collect every such entry from the progress file — select lines matching `^\[(decision|deviation)\]` — and present them in a dedicated section titled **"Decisions made autonomously / Deviations from the plan"**, one bullet per entry with its stated reason, so the user learns every question the run answered on its own and why. If there are none, state "no autonomous decisions or deviations were logged." Do this regardless of whether finalize ran — finalize is skipped on hg or when disabled, so this is the guaranteed place the user always gets the report.
- Log completion to progress file: `pwsh -File <EXEC_SKILL_DIR>/scripts/append-progress.ps1 <progress-file> "completed"`
- After every required task and check passes, move the plan to its completed/ sibling directory. Use scripts/move-plan.ps1 only when a commit is authorized. Otherwise move just the file and leave the change uncommitted.
- Report the tasks, review results, validation status, and whether the plan file moved.

## Key rules

Subagent steps assume that delegation is available and authorized. Otherwise follow their prompts and review checklists in the main session. Report the review as a main-session review.

- Each subagent gets a fresh context — no accumulated state from previous tasks
- Parent session only tracks: task number, success/failure, retry count
- Plan file is the single source of truth for progress — always re-read it
- No signals — just checkboxes in the plan for task progress
- Maintain progress file (`$env:TEMP/progress-<plan-name>.txt`) — see `prompts/progress-file.md` for format and when to write
- Update task checkboxes only after verifying the work. Keep the plan file until every task and check passes.
- Do not implement or fix code yourself — only subagents implement and fix
- If a subagent fails or leaves broken code, re-run the loop — do NOT investigate or fix it yourself
- NEVER dismiss findings as "pre-existing", "not from changes", or "architectural" — ALL findings are actionable
- NEVER summarize or filter agent findings — pass the full output to the fixer agent verbatim
- All prompt and agent files MUST be resolved through the three-layer override chain before use
- All spawned reviewers/fixers are plain `subagent` calls — the agent files provide the specialized prompt
- After reading a prompt file, substitute all placeholders before passing to subagent (see Placeholder Substitution)
- Subagents run with NO human available — they must NEVER ask the user a question (no request_user_input, no pausing for input). They decide judgment calls the plan does not settle from the project's lint rules, AGENTS.md, and code conventions, and log each as a `[decision]`/`[deviation]` line for the completion report
- In an isolated worktree the main working directory is never touched — no branch is created or checked out there and no changes land there; all git operations run inside the worktree, and Step 4's create-branch.ps1 is skipped
