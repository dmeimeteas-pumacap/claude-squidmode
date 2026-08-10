# Mode: review (interactive keep / done / drop sweep; live session only)

Also read `reference.md` (store layout, area format, guardrails). **Never run headless** — there is
no one to answer the popups. Cadence: weekly is the intended rhythm (also surfaced whenever an
area's `review_after` comes due); running it more often is fine.

Collect every area's unchecked tasks from `~/.claude/goals/goals.md`, then run a **two-pass** sweep
via **`AskUserQuestion` popups — not a typed-out table.** Default is Keep: a task not ticked in
either pass is kept and rolled. Two passes (Done, then Drop) batch all of an area's tasks into ~2
questions, which scales better than one-question-per-item.

- **Pass 1 — DONE.** One **multiSelect** question per area that has unchecked tasks. `header` = the
  area title; prompt = "Which are now DONE (completed)? Untick = not done yet." `options` = that
  area's unchecked tasks, **plus a trailing `— none done —` option** (AskUserQuestion rejects a
  single-option question — required padding). Ticked → Done.
- **Pass 2 — DROP.** One **multiSelect** question per area that *still* has open tasks after Pass 1.
  prompt = "Of what's left, tick any to DROP (abandoned — removed with a reason). Untick = keep &
  roll." `options` = the still-open tasks **plus `— none to drop —`**. Ticked → Drop.
- **Untouched in both passes → Keep (roll).**
- **Caps (hard `AskUserQuestion` limits):** ≤4 questions per call, ≤4 options per question. >4
  areas-with-tasks splits each pass across sequential calls; an area with >3 unchecked tasks splits
  across questions (3 + the sentinel = the 4-option max). Never silently truncate.
- **Done** (Pass 1) → flip `- [ ]` → `- [x]` in place (same mechanic as `manage` done; if the task
  is on today's tracker plan per the sidecar, tick there too — `modes/manage.md` done).
- **Drop** (Pass 2) → replace the task line with a dated drop record beneath the area:
  `- ~~<task>~~ dropped YYYY-MM-DD — <reason>`. Take the reason from the option's notes field, or a
  brief follow-up prompt.
- **Keep (roll)** (untouched) → leave the task `[ ]`, increment its rollover marker:
  `↻ N (since MM-DD)` (space before N; set `(since …)` to the date first rolled). Do NOT bump a task
  already rolled today, and do NOT stamp `↻ 1` on a task born this cycle. **Rollover is a signal,
  not a ritual:** a task hitting ↻ 3+ gets a coach comment — re-scope it (smaller slice), re-time it
  (wrong part of the day/week), or drop it honestly — rather than another silent roll.
- **North-star check (once per sweep, lightweight):** for any area whose tasks all rolled or
  dropped, ask whether the north-star still describes something the user wants — a dead north-star
  means retire the area (`manage` set lifecycle), not keep rolling its husk.
- **Whole-area action:** if the user signals the *entire area* is done or abandoned (e.g. via a
  popup's free-text "Other"), route it to `manage` set (extract the section to `done/<id>.md`,
  clean `links.tsv` on abandon), not an item-level edit.

Then surface any area whose `review_after` ≤ `<DATE>` and ask (popup) whether to re-evaluate it.
