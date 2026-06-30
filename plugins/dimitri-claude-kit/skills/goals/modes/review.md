# Mode: review (interactive keep / done / drop sweep; live session only)

Also read `reference.md` (file format, store layout, guardrails). **Never run headless** — there is
no one to answer the popups.

Collect every active goal's unchecked `### Daily` (and `### Weekly`) items, then run a **two-pass**
sweep via **`AskUserQuestion` popups — not a typed-out table.** Default is Keep: an item not ticked
in either pass is kept and rolled. Two passes (Done, then Drop) batch all of a goal's items into ~2
questions, which scales better than one-question-per-item when reviewing many goals at once.

- **Pass 1 — DONE.** One **multiSelect** question per goal that has unchecked items. `header` = the
  goal title; prompt = "Which items are now DONE (completed)? Untick = not done yet." `options` =
  that goal's unchecked items, **plus a trailing `— none done —` option** so the question always has
  ≥2 options (AskUserQuestion rejects a single-option question — required padding, not cosmetic).
  Ticked items → Done.
- **Pass 2 — DROP.** One **multiSelect** question per goal that *still* has open items after Pass 1
  (skip any goal whose items were all marked done). prompt = "Of what's left, tick any to DROP
  (abandon — archived with a reason). Untick = keep & carry forward." `options` = the goal's
  still-open items **plus a trailing `— none to drop —` option** (same ≥2 reason). Ticked → Drop.
- **Untouched in both passes → Keep (roll).**
- **Caps (hard `AskUserQuestion` limits):** ≤4 questions per call and ≤4 options per question. >4
  goals-with-items splits each pass across sequential calls; a goal with >3 unchecked items splits
  across multiple questions within a pass (3 items + the `— none —` sentinel = the 4-option max). Do
  not silently truncate — every unchecked item must appear in a Pass-1 popup, and every still-open
  item in a Pass-2 popup.
- **Done** (Pass 1) → flip `- [ ]` → `- [x]` in place; the item stays in its checklist as a completed
  record (same mechanic as `manage` done).
- **Drop** (Pass 2) → move the item to the goal's `## Dropped` section as
  `YYYY-MM-DD — <item> — <reason>`. Take the reason from the option's notes field, or a brief
  follow-up prompt if absent.
- **Keep (roll)** (untouched) → leave the item `[ ]`, increment its rollover marker:
  `- [ ] item ↻ 3 (since MM-DD)` (space before N; set `(since …)` to the date first rolled if not
  already present). Do NOT bump an item already rolled today (its `(since <DATE>)` equals `<DATE>`).
  An item created **this** cycle (no marker, born today) is not stale — leave it unmarked rather than
  stamping `↻ 1`.
- **Whole-goal action:** if the user signals the *entire goal* is done or abandoned (e.g. via a
  popup's free-text "Other"), that is a lifecycle change — route it to `manage` set (`status`
  done/abandoned, move `active/<id>.md` → `done/<id>.md`, clean its `links.tsv` rows), not an
  item-level edit.

Then surface any goal whose `review_after` ≤ `<DATE>` and ask (popup) whether to re-evaluate it.
Bump `last_touched` on every edited goal.
