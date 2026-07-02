# Claude Kit -- Guide

Full reference for the kit. New here? Start with **QUICKSTART.md**. Installing/updating/removing?
See **INSTALL.md**.

> **Prefer to learn by doing? Run `/tutorial`** after install — an interactive, hands-on
> walkthrough of everything below, including migrating an existing Claude setup.
>
> **The `🐤 canary` on every reply** is an optional health check from `CLAUDE.md`: if that first
> line ever goes missing or changes, it's an early signal the context is degrading and you should
> start a fresh session. Remove the Canary section in `CLAUDE.md` to disable it.

## The continuity model
Two stores, both yours and never shipped:
- **Threads** (`~/.claude/threads/active|done/<slug>.md`) -- one per *effort* tracked across days.
  Each holds `Where I left off`, `Next`, append-only `Decisions` (with rationale), and a `Log`.
  `threads/INDEX.md` is the derived dashboard.
- **Goals** (`~/.claude/goals/active|done/<id>.md`) -- longer-horizon aims (incl. non-code), with
  Daily/Weekly/Larger horizons. Goals relate to threads many-to-many via `goals/links.tsv`.

The distinction: a thread tracks *the why/where* of one effort; a goal tracks *what you're trying to
achieve* across efforts.

## The daily loop
- **Session-start hook** -- on each session it briefs you on active threads + open next items.
- **`/log`** -- capture state to a thread (Did / Thinking / Next + optional Decision). Variants:
  `/log auto` (auto-pick thread), `/log done` (tick off Next items), `/log micro` (trivial capture),
  `/log new|pause|close|fullclose` (lifecycle).
- **`/catchup`** -- resume one thread (or a date, or fuzzy topic); briefs you on where you left off.
- **`/catchupall`** -- all active threads at once.
- **`/eod`** -- cross-project synthesis of a day into `session-notes/eod-latest.md`.
- **`/eow`** -- week-to-boss roll-up.

## Goals
- **`/goals plan [week|long|all]`** -- today's derived plan + a next-action recommendation.
- **`/goals review`** -- interactive keep/done/drop sweep.
- **`/goals dump|new|set|link|done`** -- capture/sort/edit goals.

## Planning helpers
- **`grill-me`** -- relentless one-at-a-time interrogation of a plan *while it's forming*.
- **`scrutinize-plan`** -- spawns an *independent* critic that sees only the finished plan file (not
  the design chat) and returns a PROCEED / FIXES / REWORK verdict with blocking/advisory findings.
  Use it on any forward-looking plan, including implementation/architecture plans.

## Documentation skills
- **`document-process`** (one project), **`document-section`** (a group), **`document-overall`**
  (system overview), **`change-review`** (inline diff review on edits), **`skill-builder`**
  (build/revise skills).

## Hooks
- `session-start-global.sh` (SessionStart) -- the briefing. Resolves its data dir from
  `CLAUDE_CONFIG_DIR` (falls back to `$HOME/.claude`), so it works wherever the plugin lives.
- `expand-prompt.sh` (UserPromptSubmit) -- expands the `expand` keyword in prompts.
- Hooks invoke Git Bash; the installer **pins them to Git Bash's absolute path**, so PATH order doesn't
  matter (it warns only if Git Bash isn't installed; re-run `install.ps1` after a plugin update).

## Statusline + theme
`statusline.ps1` renders live usage/context meters. `/theme` is a three-layer system: a **palette**
sets the statusline gradient and, by default, the input-bar color and base theme; `bar` and `base`
are independently overridable; `/theme save` captures a look.

## Per-skill reference
See **GUIDE-skills.generated.md** -- auto-generated from each shipped skill's own description, so it
never drifts from what's installed.

## Version / updates
The kit stamps a `_kitVersion` into your `settings.json` and ships a matching marker; the session-start
hook warns if the two halves drift (re-run `install.ps1` after a `claude plugin update`). See INSTALL.md.
