---
name: goals
description: "Goal-setting + schedule-planning layer above the thread continuity system. Goals outlive any single thread, include non-code/life goals, and feed the start-of-day orientation routine. Use when the user says '/goals', 'set a goal', 'plan my day', 'what should I work on', 'review my goals', or wants to brain-dump and sort thoughts into goals. '/goals dump' turns rambling prose into proposed goals; '/goals new' runs a short capped interview; '/goals plan' shows today's derived plan + next-action recommendation; '/goals review' runs the interactive keep/done/drop sweep. NOT for capturing effort state (that is /log) or resuming an effort (that is /catchup)."
user-invocable: true
disable-model-invocation: false
argument-hint: "[new \"title\" | set <id> | dump | plan [week|long|all] | review | link <goal-id> <thread-slug> [primary|supporting|tangential] | done <id>]"
---

# Goals Skill

Goal-setting + schedule-planning above the threads. A **goal** is a separate top-level entity
(its own file) that can relate to many threads many-to-many via a junction file (`links.tsv`).
Threads track an effort's *why*; goals track *what I'm trying to achieve* across efforts. Goals
include non-code/life goals, not just project work.

Design source of truth: `~/.claude/plans/2026-06-goal-orientation-layer.md`.

## When to invoke

- `/goals`
- Setting: "set a goal", "I want to achieve X", "new goal"
- Dump: "brain-dump", "help me sort these thoughts into goals", "/goals dump"
- Planning: "plan my day", "what should I work on", "what's next", "/goals plan"
- Review: "review my goals", "roll over my unfinished items", "/goals review"

Do **not** trigger for: capturing effort state (`/log`), resuming an effort (`/catchup`), or
day-synthesis (`/eod`).

## Store layout

```
~/.claude/goals/
  links.tsv            # junction: goal-id <TAB> thread-slug <TAB> relevance
  active/<id>.md       # active + paused goals
  done/<id>.md         # completed/abandoned goals (kept readable)
```

`id` = `kebab-title`. Junction relevance ∈ {`primary`, `supporting`, `tangential`}.
The junction is the **single** store of goal↔thread edges; thread→goal is resolved at read-time by
reading `links.tsv`. Per-thread `goal:` frontmatter stays `null` (do not denormalize).

**No `INDEX.md`.** Goals are few; `plan` is the live dashboard. Do not create or maintain one.

## Goal file format (load-bearing section names)

```markdown
---
id: <kebab-id>
title: <human title>
status: active            # active | paused | done | abandoned
created: YYYY-MM-DD
last_touched: YYYY-MM-DD
priority: normal          # high | normal | low
review_after: null        # YYYY-MM-DD; surfaced by plan/review when due
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

---

## Process

### Step 1 — Determine date
Use the `currentDate` system-reminder if present; else `date +%Y-%m-%d`. Everywhere below,
`<DATE>` is this resolved date.

### Step 2 — Resolve mode (menu only when no keyword was typed)
Map the input to one of these modes:
- `new "title"` → 3a
- `set <id>` → 3b
- `dump` (or brain-dump phrasing) → 3c
- `plan [week|long|all]` → 3d
- `review` → 3e
- `link <goal-id> <thread-slug> [relevance]` → 3f
- `done <id>` → 3g

Then branch on **how** the mode was given:
- **Explicit keyword typed** (`new`, `set`, `dump`, `plan`, `review`, `link`, `done` as the argument)
  → the user has already decided. Run that mode directly. No menu, no confirm.
- **No explicit keyword — free text that *implies* a mode** (e.g. "I keep dropping the viz work"
  reads as `dump`) → keep the guided `new` walkthrough visible: read `active/*.md`, show a
  one-line-per-goal list for context, list all modes (`new "title"` (guided walkthrough), `set <id>`,
  `dump`, `plan [week]`, `review`, `link <goal-id> <thread-slug> [relevance]`, `done <id>`), state
  your read (e.g. "I read this as `dump`"), and prompt for a one-reply confirm-or-switch ("reply `go`
  to accept, or name another mode"). Do not run until the user confirms or restates — a single
  "go"/"yes"/restated-mode is enough.
- **No explicit keyword and nothing implied** (bare `/goals`) → show the same list and ask which
  mode (no default to accept).

### Step 3 — Act by mode

**3a — new (capped interview, ≤5 prompts).**
Ask, stopping after each, skipping anything already supplied in the invocation:
1. Title (required → derive `id` = kebab-title).
2. North star (1–2 lines; skippable).
3. Which horizons apply, and **≥1 actionable Daily item** (the one required output).
4. Priority (default `normal`) and optional `review_after` date.
5. Optional thread links + relevance.
If the goal is complex or long-horizon, offer to escalate to `/grill-me` instead of the capped
interview (this is a behavior of `new`, not a separate skill).
**Dedup/consolidate (before drafting the file):** once the title + north star are known, scan
existing `active/*.md` for overlap. If the new goal substantially overlaps an existing one, **do not
create a second file** — propose folding it in instead: add the new Daily/Weekly items to the
existing goal (3b-style edit) and/or add a thread link (3f), and say which existing goal you matched
and why. Only create a fresh `active/<id>.md` when no active goal covers the same ground. Bias toward
extending over creating; when the match is borderline, ask the user which goal it belongs under
rather than silently splitting. (This mirrors `dump`'s dedup step so both creation paths consolidate.)
**Review gate:** show the drafted goal file (or the proposed extension), write nothing until
approved. On approval write `active/<id>.md` with `created = last_touched = <DATE>`, and add any link
rows (3f).

**3b — set (direct edit, no interview).**
Resolve the goal by `id` (fuzzy-match the title if needed). Apply the change via a targeted edit or
a single clarifying prompt. Bump `last_touched`. **Lifecycle:** if the change sets `status` to
`done` or `abandoned`, move the file `active/<id>.md` → `done/<id>.md`; if back to `active`/`paused`,
keep/return it to `active/`.

**3c — dump (prose → proposed goals).**
Pipeline:
1. Ingest the prose (from the argument, or ask the user to paste it).
2. Segment into candidate goals.
3. Per candidate: draft title + north-star, classify items into `Daily`/`Weekly`/`Larger`, and
   **force ≥1 actionable Daily item** — if a candidate is pure musing, file it as `Larger` prose
   rather than faking a task.
4. **Dedup against existing `active/*.md`**: if a candidate overlaps an existing goal, propose
   extending/linking it, not a new file.
5. Suggest thread links + relevance.
6. **Mandatory review gate** — present the full proposed set; write nothing until approved.
Guardrail: **bias toward fewer/broader goals.** Merge aggressively, cap new goals at ~3 per dump,
and flag any over-broad candidate to split rather than silently creating many. On approval, write/
merge the `active/<id>.md` files, add `links.tsv` rows, bump `last_touched`.

**3d — plan (derived view; writes nothing to the store).**
1. Read all `active/*.md`. Collect unchecked horizon items per the arg, each tagged with its goal
   title. The arg selects WHICH horizon(s) to show (each variant shows only what it names):
   - (no arg) → `### Daily` only.
   - `week` → `### Weekly` only.
   - `long` → `### Larger` only (the long-term / monthly horizon; render its prose as-is when it is
     not a checklist).
   - `all` → `### Daily` + `### Weekly` + `### Larger`, grouped by horizon.
1b. **Live progress for ledger-backed goals.** If a goal's frontmatter carries a `live_progress`
   block (`cmd` + `pattern`), run `cmd` and parse `pattern` (a regex whose first two capture groups
   are done/total) out of its output. Use that LIVE count as the goal's `progress` in the box meta
   tag and in the recommendation — it overrides any number in the item text or a stale snapshot,
   because a ledger-backed count drifts the moment a verdict is recorded. Display-only: `plan` still
   writes nothing, so the goal file's own text may lag the live count (that is expected — the live
   read is the truth shown). If `cmd` fails or is unreachable (tool moved, not on this machine),
   fall back to the item text and surface a `▲ FLAG` row noting the live count could not be read.
2. Via `links.tsv`, find threads linked to active goals; read those threads' `## Next` items.
3. Surface any goal whose `review_after` ≤ `<DATE>` as due-for-review.
4. Read `~/.claude/session-notes/eod-latest.md` as a digest source (in-progress + tomorrow's
   priorities) for context. Best-effort — skip if absent.
5. **Flag (do not merge)** obvious duplicates across goal-`Daily` and thread-`Next`.
6. End with a **next-action recommendation**: given active goals, priorities, the declared
   primary/big-rock, and any stated energy/blockers, recommend what to work on now and in what
   order, with reasoning. Encode: importance ≠ urgency ≠ readiness (deprioritize blocked/undefined/
   already-worked-around items even if labeled high); protect the declared primary and do demanding
   work while fresh; use quick-wins as momentum or breaks, not day-eaters; name the EF pattern at
   play and point at the smallest concrete next step. Give a definitive recommendation with a clear
   default plus at most one caveat — **not** an even-handed menu.
7. Render the plan as a single ASCII box inside one fenced ```text code block (copy-paste-ready,
   lifted out whole). This box layout is the STANDARD plan output — always use it, not a bare list.
   Console echo only — `plan` still writes nothing to the store.
   Structure:
   - Header line: `PLAN — <Weekday YYYY-MM-DD>`. Optional second line for staleness/context (e.g.
     last EOD date, intervening non-work days).
   - **Two-line layout per goal (standard).** Each goal is rendered as exactly two content rows:
     1. Header row: `  <symbol> <TIER>  <label>   [<priority · progress>]` — 2-space margin, the
        fixed-meaning symbol, the tier word padded to a fixed column (8) so all labels start at the
        same column, the item label, then the meta tag in brackets. (goal-id is omitted from the
        box to save width; it lives in the tag elsewhere — keep `priority · progress` here.)
     2. Next-action row: indented to align the `→` directly under the label column (NOT a third
        indent stop), stating the smallest concrete next step.
     One blank content row between goals. This single-indent-stop alignment is deliberate — the
     `→` under the label is the whole point; do not reintroduce a third indent level.
   - Tier symbols (use only the ones that apply; order them as listed):
     - `★` PRIMARY — the declared big-rock / no-exceptions item; do it first, while fresh.
     - `●` MUST — a today-must that comes after the primary is banked.
     - `◐` BREAK — an earned, lower-stakes step-away (e.g. tooling polish), not a day-eater.
     - `◇` STRETCH — nice-to-have only.
     - `○` STEP-BACK — secondary / variety work that must not displace the primary.
     - `▽` BACKBURNER — explicitly deprioritized this cycle.
     - `▲` FLAG — overdue review (`review_after` passed), blocker, or duplicate to surface.
   - Keep each line to one row; clip long labels rather than wrapping inside the box.
   - **Uniform width (required).** The box must be a perfect rectangle: pick one inner width W, and
     EVERY content line is padded with trailing spaces so its closing `│` lands in the same column.
     The top/bottom borders span the same W. Procedure: render each line's text, measure its display
     width, then pad to W (or clip with `…` if it exceeds W) BEFORE appending the closing `│`. Never
     let a long line push its border out or a short line pull it in — a ragged right edge is the
     failure this rule exists to prevent.
   - **Breathing room (required).** Favor readability over compactness — the box MAY extend well to
     the right; do not cram. Default inner width W = 100 (widen further if labels need it; never
     shrink to make text fit on one screen). 2-space left margin inside the bar, generous trailing
     space on the right, a leading blank row after the header border, and a blank content row
     (`│` + W spaces + `│`) between goals so the tiers don't run together.
   - **Single-width symbols only.** All tier symbols (`★ ● ◐ ◇ ○ ▽ ▲`) are single display-width, so
     codepoint count equals column count and the padding math stays exact. Do NOT introduce emoji or
     other double-width glyphs into the box — they silently break alignment even when character
     counts match.

**3e — review (interactive keep / done / drop sweep; live session only).**
Collect every active goal's unchecked `### Daily` (and `### Weekly`) items, then run a **two-pass**
sweep via **`AskUserQuestion` popups — not a typed-out table.** Default is Keep: an item not ticked
in either pass is kept and rolled. Two passes (Done, then Drop) batch all of a goal's items into ~2
questions, which scales better than one-question-per-item when reviewing many goals at once.
- **Pass 1 — DONE.** One **multiSelect** question per goal that has unchecked items. `header` = the
  goal title; prompt = "Which items are now DONE (completed)? Untick = not done yet." `options` =
  that goal's unchecked items, **plus a trailing `— none done —` option** so the question always has
  ≥2 options (AskUserQuestion rejects a single-option question — this padding is required, not
  cosmetic). Ticked items → Done.
- **Pass 2 — DROP.** One **multiSelect** question per goal that *still* has open items after Pass 1
  (skip any goal whose items were all marked done). prompt = "Of what's left, tick any to DROP
  (abandon — archived with a reason). Untick = keep & carry forward." `options` = the goal's
  still-open items **plus a trailing `— none to drop —` option** (same ≥2 reason). Ticked → Drop.
- **Untouched in both passes → Keep (roll).**
- **Caps (hard `AskUserQuestion` limits):** ≤4 questions per call and ≤4 options per question. >4
  goals-with-items splits each pass across sequential calls; a goal with >3 unchecked items splits
  across multiple questions within a pass (3 items + the `— none —` sentinel = the 4-option max).
  Do not silently truncate — every unchecked item must appear in a Pass-1 popup, and every still-open
  item in a Pass-2 popup.
- **Done** (Pass 1) → flip `- [ ]` → `- [x]` in place; the item stays in its checklist as a
  completed record (same mechanic as mode 3g).
- **Drop** (Pass 2) → move the item to the goal's `## Dropped` section as
  `YYYY-MM-DD — <item> — <reason>`. Take the reason from the option's notes field, or a brief
  follow-up prompt if absent.
- **Keep (roll)** (untouched) → leave the item `[ ]`, increment its rollover marker:
  `- [ ] item ↻ 3 (since MM-DD)` (space before N; set `(since …)` to the date first rolled if not
  already present). Do NOT bump an item already rolled today (its `(since <DATE>)` equals `<DATE>`).
  An item created **this** cycle (no marker, born today) is not stale — leave it unmarked rather than
  stamping `↻ 1`.
- **Whole-goal action:** if the user signals the *entire goal* is done or abandoned (e.g. via a
  popup's free-text "Other"), that is a lifecycle change — route it to mode 3b (set `status`
  done/abandoned, move `active/<id>.md` → `done/<id>.md`, clean its `links.tsv` rows), not an
  item-level edit.
Then surface any goal whose `review_after` ≤ `<DATE>` and ask (popup) whether to re-evaluate it.
Bump `last_touched` on every edited goal. Never run headless — there is no one to answer the popups.

**3f — link (junction edge management).**
Add or edit a row in `links.tsv`: `goal-id <TAB> thread-slug <TAB> relevance` (TAB-separated;
default relevance `supporting`). Validate the goal exists (`active/` or `done/`) and the thread
exists (`~/.claude/threads/active/` or `/done/`). One edge per goal-thread pair — if the pair
already exists, update its relevance in place rather than appending a duplicate row. Query either
direction by reading the file (goal→threads or thread→goals).

**3g — done (check off horizon items).**
Resolve the goal by `id`. Show its unchecked `### Daily`/`### Weekly` items; the user picks which
are complete. Flip `- [ ]` → `- [x]` for those. Bump `last_touched`. (This mirrors `/log done`'s
tick mechanic but operates on goal horizon checklists — no coupling to `/log`.) Completing the
*whole goal* is a `set` status change (3b), not this mode.

### Step 4 — Maintain `last_touched`
Bump `last_touched` to `<DATE>` on any goal file written. No INDEX to update.

---

## Guardrails

- **Single-writer.** Goals own their horizon items + `## Dropped`; `links.tsv` is the sole edge
  store; threads own `## Next`. Never duplicate an edge into thread frontmatter.
- `plan` and any reconstruction-style read write **nothing**.
- `review`'s keep/done/drop is interactive only — never run it from a headless/scheduled context.
- `dump` writes nothing before the review gate.
- Do not modify `eod`, the session-start hook, or thread files from this skill.
- Headless `claude -p` writing under `~/.claude/` needs `--permission-mode bypassPermissions` —
  relevant only if a goal action is ever scheduled (goal writes are normally interactive/live).

## Gotchas

- `↻ N` needs the space (`↻ 3`, not `↻3`) — in the stored marker AND anywhere the marker is rendered to the user (the `plan` box, `review` prompts, and any chat summary or table). Never collapse it to `↻N`.
- `links.tsv` is TAB-separated. When editing on Windows, preserve real tabs (do not let an editor
  expand them to spaces); PowerShell `-Encoding utf8` writes a BOM that can corrupt parsing —
  prefer ASCII/UTF-8-no-BOM. See memory `powershell-bom-breaks-json`.
- Dangling junction rows after a thread is deleted are not auto-cleaned — a lint/janitor pass is a
  future addition. `link` queries should tolerate a row whose thread file is gone.
- `id` = kebab-title; only add a date prefix if a collision actually appears.

## Versioning

- If the trigger misfires (esp. vs `/log` / `/catchup` / `/eod`) → tighten the `description` first.
- If `dump` segmentation over-fragments → strengthen the fewer/broader-goals guardrail + add a gotcha.
- When the thread or `eod` formats change → update the `plan` aggregation + read-time resolution.
