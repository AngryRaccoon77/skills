---
name: brainstorm
description: "Use before any creative work or significant changes. Activates on \"brainstorm\", \"let's brainstorm\", \"deep analysis\", \"analyze this feature\", \"think through\", \"help me design\", \"explore options for\", or when the user asks for thorough analysis of changes, features, or architectural decisions."
---

# Brainstorm

For Codex, use the tools available in the current client. Ask a needed question in chat if the question tool is unavailable.

Turn ideas into designs through collaborative dialogue before implementation.

Resolve bundled relative paths from the directory that contains this SKILL.md.

## custom rules loading

before starting, run this command via the shell tool (`pwsh`) from the project working directory:

```powershell
pwsh -File scripts/resolve-rules.ps1 brainstorm-rules.md
```

if the output is non-empty, treat it as additional instructions that supplement (not replace) the built-in rules below. apply custom rules alongside the skill's own instructions throughout the brainstorm process — they may influence design preferences, naming conventions, technology choices, or other aspects of the brainstorm session. custom rules content is guidance for the brainstorm dialogue, not content to embed verbatim in the output.

### rules management

when the user asks to add, show, or clear custom brainstorm rules, handle these operations:

- **show rules**: run the resolve command above and display the output. if the output is empty, tell the user no custom rules are configured at either level. otherwise, determine the source by checking whether `.codex/rules/brainstorm-rules.md` exists and is non-empty (project-level) — if not, the output came from user-level. tell the user which level it came from.
- **add/update project rules**: write content to `.codex/rules/brainstorm-rules.md` in the current working directory (create directories as needed).
- **add/update user rules**: write content to `$HOME/.codex/rules/brainstorm-rules.md`.
- **clear project rules**: delete `.codex/rules/brainstorm-rules.md`.
- **clear user rules**: delete `$HOME/.codex/rules/brainstorm-rules.md`.

project-level rules (`.codex/rules/brainstorm-rules.md`) take precedence over user-level rules (`$HOME/.codex/rules/brainstorm-rules.md`). when both non-empty files exist, only project-level rules are loaded. empty files are treated as absent and fall through to the next level. see `references/custom-rules.md` for full documentation on the rules mechanism.

**CRITICAL: this skill must NEVER modify its own files (SKILL.md, scripts, references). the ONLY files it may create or modify for rules management are `.codex/rules/brainstorm-rules.md` and `$HOME/.codex/rules/brainstorm-rules.md`. if the user asks to change the skill's behavior, suggest creating a plan — do not edit skill files directly.**

## Process

### Phase 1: Understand the Idea

Check project context first, then ask questions one at a time:

1. **Gather context** - check files, docs, recent commits relevant to the idea
2. **Ask questions one at a time** - prefer multiple choice when possible (use the Codex question tool when available)
3. **Focus on**: purpose, constraints, success criteria, integration points

Do not overwhelm with multiple questions. One question per message. If a topic needs more exploration, break it into multiple questions.

### Phase 2: Explore Approaches

Once the problem is understood:

1. **Propose 2-3 different approaches** with trade-offs
2. **Lead with recommended option** and explain reasoning
3. **Present conversationally** - not a formal document yet

Example format:
```
I see three approaches:

**Option A: [name]** (recommended)
- how it works: ...
- pros: ...
- cons: ...

**Option B: [name]**
- how it works: ...
- pros: ...
- cons: ...

Which direction appeals to you?
```

### Phase 3: Present Design

After approach is selected:

1. **Break design into sections** of 200-300 words each
2. **Ask after each section** whether it looks right
3. **Cover**: architecture, components, data flow, error handling, testing
4. **Be ready to backtrack** if something doesn't make sense

Do not present entire design at once. Incremental validation catches misunderstandings early.

### Phase 4: Next Steps

After design is validated, use the Codex question tool when available:

```json
{
  "questions": [{
    "question": "Design looks complete. What's next?",
    "header": "Next step",
    "options": [
      {"label": "Write plan", "description": "Create docs/plans/yyyymmdd-<task-name>.md with implementation steps via the planning-make skill"},
      {"label": "Plan mode", "description": "Enter plan mode (Plan mode) for structured implementation planning"},
      {"label": "Start now", "description": "Begin implementing directly"}
    ]
  }]
}
```

- **Write plan**: invoke the `planning-make` skill to create the plan file. Pass brainstorm context (discovered files, selected approach, design decisions) as input so the plan skill has full context without re-asking questions
- **Plan mode**: switch to plan mode for detailed planning with user approval workflow
- **Start now**: proceeds directly if design is simple enough

## Key Principles

- **One question at a time** - do not overwhelm with multiple questions
- **Multiple choice preferred** - easier to answer than open-ended when possible
- **YAGNI ruthlessly** - remove unnecessary features from all designs, keep scope minimal
- **Explore alternatives** - always propose 2-3 approaches before settling
- **Incremental validation** - present design in sections, validate each
- **Be flexible** - go back and clarify when something doesn't make sense
- **Lead with recommendation** - have an opinion, explain why, but let user decide
- **Duplication vs abstraction** - when code repeats, ask user: prefer duplication (simpler, no coupling) or abstraction (DRY but adds complexity)? explain trade-offs before deciding

## Task Tracking

When implementing after brainstorm:
- Track implementation tasks using `update_plan`
- Mark each task as completed immediately when done (do not batch)
- Keep user informed of progress through status updates
