# Planning Skills Usage

The planning adaptation has two skills: `planning-make` (plan creation) and `planning-exec` (autonomous execution), plus a plan-review subagent prompt bundled with make.

## Make — `planning-make`

### Triggers
- "make a plan", "plan <description>", "create an implementation plan"
- invoked automatically by brainstorm when user picks "Write plan"

### Workflow
1. **Step 0** — parses intent (feature, bug fix, refactor, migration) and explores codebase for context
2. **Step 1** — asks focused questions one at a time: goal, scope, constraints, testing approach, title
3. **Step 1.5** — proposes 2-3 implementation approaches with trade-offs (skipped if obvious)
4. **Step 2** — creates plan file at `docs/plans/yyyymmdd-<task-name>.md`
5. **Step 3** — offers next steps: manual review, auto review, implement, or done

### Examples
```
"make a plan to add user authentication"
"plan a fix for the race condition in the connection pool"
"create an implementation plan: refactor the middleware stack"
"add my Go testing rules to user-level planning rules"
```

### Plan File Structure
- Overview, Context, Development Approach, Testing Strategy
- Implementation Steps with `### Task N:` sections
- Each task has `**Files:**` block and `[ ]` checkboxes
- Progress tracking with `[x]`, ➕, ⚠️ markers

## Exec — `planning-exec`

### Triggers
- "exec <plan-file>", "execute plan", "run plan"

### Workflow
1. Resolves plan file (from argument or picks from `docs/plans/`)
2. Asks about worktree isolation (worktree vs current directory)
3. Creates a feature branch
4. Executes tasks sequentially — one subagent per task, commits after each
5. Runs multi-phase review: comprehensive (iteration 1) then critical re-check loop → code smells → external (codex) → critical-only
6. Optional finalize: rebase and squash commits
7. Stats summary: aggregate per-phase tokens/duration + git diff stats and report

### Configuration
There is no plugin-install config prompting — answer these upfront when invoking the skill or use the defaults:

| Key | Default | Description |
|-----|---------|-------------|
| `external_review_cmd` | *(auto-detect codex)* | external review tool command |
| `task_retries` | `1` | retries for failed tasks |
| `review_iterations` | `5` | max fix-and-recheck cycles |
| `external_review_iterations` | `10` | max external review iterations |
| `finalize_enabled` | `true` | run rebase + squash phase |
| `plans_dir` | `docs/plans` | directory for plan files |

### Customization
Prompts and agent definitions use a three-layer override chain:
1. Project: `.codex/exec-plan/prompts/` and `.codex/exec-plan/agents/` in the working directory
2. User: `$HOME/.codex/rules/exec-plan/prompts/` and `$HOME/.codex/rules/exec-plan/agents/`
3. Bundled defaults (in the skill's `references/`)

Resolution is always done by `scripts/resolve-file.ps1` — never constructed manually.

### Customization patterns

- *Route review fanout to named specialists.* Override `prompts/review.md` to launch differently-scoped read-only reviewer subagents instead of the generic ones.
- *Delegate to an existing skill.* Override a prompt or agent file to instruct the spawned subagent to load another skill via the `skill` tool and follow its workflow inline.

### Subagent constraint

Subagents cannot spawn other subagents — there is no fan-out from inside a child. `prompts/review.md` is therefore read by the main session orchestrator (as a playbook), not given to a subagent. The parallel specialist fanout runs directly from the main session by issuing several `subagent` tool calls in ONE response. Leaf-work prompts (`task.md`, `fixer.md`, `finalizer.md`, `codex-review.md`, `agents/smells.txt`) can be subagent prompts because they don't need to spawn further. Any custom override needing parallel fanout must follow the same playbook pattern.

## Plan-Review

### Triggers
- launched by planning-make's "Auto review" option as a `subagent` whose prompt is `references/plan-review-agent.md`

### What It Checks
- problem definition and solution correctness
- scope creep and over-engineering
- testing requirements and coverage
- task granularity and ordering
- convention adherence (via AGENTS.md and custom rules)

### Output
Structured report with severity-rated findings:
- Critical Issues, Important Issues, Minor Issues
- Over-Engineering Concerns
- Testing Coverage Assessment
- Verdict: APPROVE or NEEDS REVISION

## Manual Plan Review

After creating a plan, planning-make offers manual review: you annotate the plan file directly (any editor/GUI diff view) or send a change-list message; the skill revises the plan and loops until you are satisfied.
