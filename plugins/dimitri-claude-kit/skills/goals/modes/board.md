# Mode: board (bare `/goals`, or `/goals week|long|all`)

Derived dashboard. **Writes nothing.** This is the hot path — keep the read scoped. Do NOT load
`reference.md` here.

## 1 — Scoped read (do not `cat` whole goal files)
Read only each active goal's **frontmatter** + the **requested horizon section**. The Larger /
Requirements / Reminder-mechanism prose is dead weight in context for a board pull — skip it.

Goal files supply frontmatter + the WEEKLY/LARGER horizons. **DAILY is NOT read from goal files** —
it comes from the task-tracker (the single source of truth for today, shared with `/goals today` and
the feed widget). Goal-file `### Daily` sections no longer drive the board (retire them in cleanup).

```bash
cd ~/.claude/goals/active
for f in *.md; do
  echo "=== $f ==="
  awk 'c<2{print} /^---$/{c++}' "$f"                                            # frontmatter (through 2nd ---)
  awk '/^### (Weekly|Larger)$/{print;p=1;next} /^### /{p=0} /^## /{p=0} p' "$f"  # weekly + larger blocks
done
```
Then read DAILY from the task-tracker (single source): `task-tracker show` (i.e.
`~/.claude/accountability/task-tracker.ps1 show`), which prints the day's primary + musts with tick state.

Collect items for the requested horizon:
- (no arg) → the **broad view**. **DAILY** = the task-tracker, rendered **abbreviated**: the primary
  line + open/done counts + a single `run /goals today` pointer (NOT the full task list). **WEEKLY +
  LARGER** = each goal file's `### Weekly`/`### Larger`, in full. The bare board is the zoomed-out
  picture; the day's full detail lives in `/goals today`.
- `week` → `### Weekly` only (swap the heading in the second awk).
- `long` → `### Larger` only (render its prose as-is when it is not a checklist).
- `all` → same as the broad view but **DAILY in full** (the task-tracker's whole list with tick state,
  not just counts), plus WEEKLY + LARGER in full, grouped by horizon.

## 1b — Live progress for ledger-backed goals
If a goal's frontmatter carries a `live_progress` block (`cmd` + `pattern`), run `cmd` and parse
`pattern` (a regex whose first two capture groups are done/total). Use that LIVE count as the goal's
`progress` in the box meta tag and in the recommendation — it overrides any number in the item text
or a stale snapshot, because a ledger-backed count drifts the moment a verdict is recorded.
Display-only: the board writes nothing, so the goal file's own text may lag (expected — the live read
is the truth shown). If `cmd` fails or is unreachable, fall back to the item text and surface a
`▲ FLAG` row noting the live count could not be read.

## 2 — Linked thread Next items
Via `links.tsv`, find threads linked to active goals; read those threads' `## Next` items.

## 3 — Reviews due
Surface any goal whose `review_after` ≤ `<DATE>` as due-for-review (`▲ FLAG`).

## 4 — EOD digest (best-effort)
Read `~/.claude/session-notes/eod-latest.md` for context (in-progress + tomorrow's priorities). Skip
if absent.

## 5 — Flag duplicates (do not merge)
Flag obvious duplicates across goal-`Daily` and thread-`Next`.

## 6 — Next-action recommendation
Given active goals, priorities, the declared primary/big-rock, and any stated energy/blockers,
recommend what to work on now and in what order, with reasoning. Encode: importance ≠ urgency ≠
readiness (deprioritize blocked/undefined/already-worked-around items even if labeled high); protect
the declared primary and do demanding work while fresh; use quick-wins as momentum or breaks, not
day-eaters; name the EF pattern at play and point at the smallest concrete next step. Give a
definitive recommendation with a clear default plus at most one caveat — **not** an even-handed menu.

## 7 — Render the box
Render as a single ASCII box inside one fenced ```text code block (copy-paste-ready, lifted out
whole). This box layout is the STANDARD board output — always use it, not a bare list.

- Header line: `GOALS BOARD — <Weekday YYYY-MM-DD>`. Optional second line for staleness/context
  (e.g. last EOD date, intervening non-work days).
- **Horizon-grouped layout (standard for the broad board and `all`).** Group the open items under
  horizon sub-headers so weekly vs longer-term is unmistakable: a `--- DAILY ---`, `--- WEEKLY ---`,
  and `--- LARGER ---` divider line, with that horizon's open items beneath it. One line per item:
  `  <symbol> [<goal-id>] <terse item / smallest next step>` — 2-space margin, the fixed-meaning tier
  symbol, the goal id in brackets (padded to a fixed column so the text aligns), then a one-line gist
  (clip, do not wrap).
  - **DAILY group — sourced from the task-tracker, always present.** On the **bare** board render it
    ABBREVIATED: the primary line (with its `★`) + open/done counts, plus a single pointer
    `run /goals today for the full day` — e.g. `★ Matt's notepad review` / `2 done · 4 open`. On
    `/goals all`, render the tracker's full task list with tick state. Show the `--- DAILY ---` header
    even when no plan is set (`(no plan set — run /goals today)`).
  - **WEEKLY / LARGER groups** are rendered in full (Larger as a one-line prose gist per goal when it
    is not a checklist). These two distinct headers are what make weekly-vs-longer-term explicit.
- **Tier assignment differs on the board.** On `/goals today`, `★` = today's declared task-tracker
  primary and tiers track the day's plan. On the bare/broad board, tiers express each goal's
  **standing priority/value across the week**, NOT today's task. Assign a **spread** across the symbol
  set so the board shows the value gradient rather than collapsing to one priority: high-priority
  goals → `★`/`●`, normal → `○`, low/deprioritized → `▽`, stretch/nice-to-have → `◇`, and `▲` for any
  overdue-review / blocker / duplicate. Use `★` sparingly — at most the single clear big-rock goal, or
  none — because the board's value is the relative ranking, not a lone primary.
- Tier symbols (use only the ones that apply; order as listed):
  - `▸` QUICKSTART — a quick win to knock out first for momentum; leads even the primary. Not a big rock; a fast, low-commitment task done ahead of the anchors.
  - `★` PRIMARY — the declared big-rock / no-exceptions item; the day's anchor.
  - `●` MUST — a today-must that comes after the primary is banked.
  - `◐` BREAK — an earned, lower-stakes step-away (e.g. tooling polish), not a day-eater.
  - `◇` STRETCH — nice-to-have only.
  - `○` STEP-BACK — secondary / variety work that must not displace the primary.
  - `▽` BACKBURNER — explicitly deprioritized this cycle.
  - `▲` FLAG — overdue review (`review_after` passed), blocker, or duplicate to surface.
- Keep each line to one row; clip long labels rather than wrapping inside the box.
- **Uniform width (required).** The box must be a perfect rectangle: pick one inner width W; EVERY
  content line is padded with trailing spaces so its closing `│` lands in the same column. Top/bottom
  borders span the same W. Procedure: render each line's text, measure its DISPLAY width (character
  count, not bytes — `·`, `→`, `↻`, `—` and the tier glyphs are multi-byte but single-column), then
  pad to W (or clip with `…`) BEFORE appending the closing `│`. A ragged right edge is the failure
  this rule exists to prevent. (When generating with a shell, pad by character count — e.g. perl
  `-CSDA` `length()`, NOT `awk`/`wc -c` which count bytes.)
- **Breathing room (required).** Favor readability over compactness — the box MAY extend well to the
  right. Default inner width W = 100 (widen if labels need it; never shrink to fit one screen).
  2-space left margin, generous trailing space, a leading blank row after the header border, and a
  blank content row between goals.
- **Single-width symbols only.** All tier symbols (`▸ ★ ● ◐ ◇ ○ ▽ ▲`) are single display-width (`▸`
  is U+25B8, the small text-presentation triangle — NOT U+25B6 `▶`, which is emoji-width). Do NOT
  introduce emoji or other double-width glyphs — they silently break alignment even when character
  counts match.

## 8 — Footer (mode discovery)
After the box, print one line so modes stay discoverable (bare `/goals` is no longer a menu):

`modes: /goals today · plan · new "title" · dump · review · set <id> · link <goal> <thread> · done [<id>] · week|long|all`
