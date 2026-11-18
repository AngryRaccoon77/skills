# Custom Rules for Planning

Custom rules let you inject project-specific or personal conventions into the planning workflow (make, exec, plan-review). Rules are free-form markdown loaded at skill invocation time and applied as additional instructions alongside the skill's built-in behavior.

## File Locations

Two levels, checked in order (first-found-wins, never merged):

1. **Project-level**: `.codex/rules/planning-rules.md` in the current working directory
2. **User-level**: `$HOME/.codex/rules/planning-rules.md`

When both non-empty files exist, only the project-level file is used. Empty files are treated as absent and fall through to the next level.

## Resolution

Each skill runs `scripts/resolve-rules.ps1 planning-rules.md` via the shell tool (`pwsh`) at startup. The script prints the first file found (project, then user) or empty output if neither exists.

## Managing Rules

Ask the planning-make skill to manage rules:

- **show rules** — displays current rules and which level they came from
- **add/update project rules** — writes to `.codex/rules/planning-rules.md`
- **add/update user rules** — writes to `$HOME/.codex/rules/planning-rules.md`
- **clear project rules** — deletes `.codex/rules/planning-rules.md`
- **clear user rules** — deletes `$HOME/.codex/rules/planning-rules.md`

## Example Content

```markdown
## testing conventions
- use table-driven tests with testify
- mock external dependencies with moq
- aim for 80% coverage minimum

## naming
- use camelCase for local variables
- keep function names under 30 characters

## plan structure preferences
- max 5 checkboxes per task
- always include rollback steps for migrations
```

## How Rules Apply

- **planning-make**: rules influence plan structure, testing approach, naming conventions, task granularity
- **plan-review** (subagent): rules become additional review criteria for convention adherence
- **planning-exec**: rules propagate to task subagents via the `USER_RULES` placeholder in task prompts

Rules supplement built-in instructions — they never replace them.
