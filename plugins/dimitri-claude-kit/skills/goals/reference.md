# Goals — shared reference (loaded by write modes: new, dump, review, manage)

## Store layout

```
~/.claude/goals/
  links.tsv            # junction: goal-id <TAB> thread-slug <TAB> relevance
  active/<id>.md       # active + paused goals
  done/<id>.md         # completed/abandoned goals (kept readable)
```

`id` = `kebab-title`. Junction relevance ∈ {`primary`, `supporting`, `tangential`}. The junction is
the **single** store of goal↔thread edges; thread→goal is resolved at read-time by reading
`links.tsv`. Per-thread `goal:` frontmatter stays `null` (do not denormalize).

**No `INDEX.md`.** Goals are few; the board (bare `/goals`) is the live dashboard. Do not create one.

## Goal file format (load-bearing section names)

```markdown
---
id: <kebab-id>
title: <human title>
status: active            # active | paused | done | abandoned
created: YYYY-MM-DD
last_touched: YYYY-MM-DD
priority: normal          # high | normal | low
review_after: null        # YYYY-MM-DD; surfaced by board/review when due
---

# <title>

## North star
<1–2 lines, horizon-agnostic objective. Prose.>

## Horizons
### Daily
- [ ] <actionable; sub-items may nest; ↻ N (since MM-DD) on rollover — space before N>
### Weekly
- [ ] ...
### Larger
<prose direction, or checklist once actionable>

## Dropped
- YYYY-MM-DD — <dropped item> — <one-line reason>
```

A goal includes only the horizons that apply. Daily/Weekly are checklists (actionable,
roll-forwardable). Larger may be prose — do not fabricate fake tasks.

## Maintain `last_touched`
Bump `last_touched` to `<DATE>` on any goal file written.

## Guardrails

- **Single-writer.** Goals own their horizon items + `## Dropped`; `links.tsv` is the sole edge
  store; threads own `## Next`. Never duplicate an edge into thread frontmatter.
- The board and any reconstruction-style read write **nothing**. `plan` writes nothing to the goals
  store (it hands off to `/today`).
- `review`'s keep/done/drop is interactive only — never run it from a headless/scheduled context.
- `dump` writes nothing before the review gate.
- Do not modify `eod`, the session-start hook, or thread files from this skill.
- Headless `claude -p` writing under `~/.claude/` needs `--permission-mode bypassPermissions` —
  relevant only if a goal action is ever scheduled (goal writes are normally interactive/live).

## Gotchas

- `↻ N` needs the space (`↻ 3`, not `↻3`) — in the stored marker AND anywhere it is rendered to the
  user (the board box, `review` prompts, any chat summary). Never collapse it to `↻N`.
- `links.tsv` is TAB-separated. When editing on Windows, preserve real tabs (do not let an editor
  expand them to spaces); PowerShell `-Encoding utf8` writes a BOM that can corrupt parsing — prefer
  ASCII/UTF-8-no-BOM. See memory `powershell-bom-breaks-json`.
- Dangling junction rows after a thread is deleted are not auto-cleaned — a lint/janitor pass is a
  future addition. `link` queries should tolerate a row whose thread file is gone.
- `id` = kebab-title; only add a date prefix if a collision actually appears.

## Versioning

- If the trigger misfires (esp. vs `/log` / `/catchup` / `/eod` / `/today`) → tighten the router
  `description` first.
- If `dump` segmentation over-fragments → strengthen the fewer/broader-goals guardrail + add a gotcha.
- When the thread or `eod` formats change → update `modes/board.md` aggregation + read-time resolution.
- Mode files live in `modes/`; shared store/format rules live here. Keep the router thin.
