# Mode: board (bare `/goals`, or `/goals week|long|all`)

Derived dashboard AND the status report — this absorbed `/current` (2026-07-31): today's tasks +
area progress (live counts) + open thread `## Next` items + drift footer, one view. **Writes
nothing.** This is the hot path — keep the read scoped. Do NOT load `reference.md` here.

## 1 — Read the store (one file now)
Read `~/.claude/goals/goals.md` — the single area store. Each `## ` section = an area: metadata line
(`id: … · prio: <n> · review_after: …`), optional `live_progress:` / `thread:` lines, `north-star:`,
then its task list (`- [ ]` items with `{deadline|this-week|evergreen}` tags and `↻ N` rollovers,
possibly with `> note` lines beneath).

**DAILY is NOT read from goals.md** — it comes from the day store `~/.claude/accountability/today.md`
(the single source of truth for today, owned by `/today`; format in `modes/today.md`). Read it
directly.

Scope by argument:
- (no arg) → the **broad view**. **DAILY** = the day store, rendered **abbreviated**: the primary
  line + open/done counts + a single `run /today` pointer (NOT the full task list). **AREAS** =
  every area's open tasks in full, grouped per area, prio order.
- `week` → only tasks tagged `{this-week}` or `{deadline:…}` falling within 7 days.
- `long` → only `{evergreen}` tasks + each area's north-star line.
- `all` → the broad view but DAILY in full (the day store's whole list with tick state), plus every
  area's full task list including `- [x]` completed records.

## 1b — Live progress for ledger-backed areas
If an area carries a `live_progress:` line (`` `cmd` → `pattern` ``), get its live count from the
shared detector rather than re-running commands ad hoc:
```
powershell -NoProfile -File "%USERPROFILE%\.claude\janitor\detect-drift.ps1" -Quiet
```
then read the `live` array from `~/.claude/janitor/drift-latest.json` (`{goal, ok, num, den, pct}`).
Use the LIVE count in the area's meta tag and the recommendation — it overrides any number in task
text. Display-only. If `ok:false` (or the detector is absent — then run the area's cmd inline as
fallback), fall back to task text and surface a `▲ FLAG` row noting the live count could not be
read. Respect env preconditions (e.g. the audit's `Audit.ps1` only reports correctly on the
**Dimitri branch** — memory `audit-ledger-check-dimitri-branch`); if a count looks off, name the
precondition, don't trust it.

## 2 — Linked thread Next items
Via `links.tsv` (area-id → thread-slug), read each linked ACTIVE thread's `## Next` and collect the
open (`- [ ]`) items, one line each (top 4 + `(+N more)` per thread). Close with any active thread
no area links (nothing silently dropped). These are alignment pointers (thread = memory), shown so
the board is the one-stop view — flag obvious divergence from area tasks, do not merge.

## 3 — Reviews due
Surface any area whose `review_after` ≤ `<DATE>` as due-for-review (`▲ FLAG`).

## 4 — EOD digest (best-effort)
Read `~/.claude/session-notes/eod-latest.md` for context (in-progress + tomorrow's priorities). Skip
if absent.

## 5 — Flag duplicates (do not merge)
Flag obvious duplicates between area tasks and thread `## Next` pointers.

## 6 — Next-action recommendation
Given the areas, priorities, the declared tracker primary, and any stated energy/blockers, recommend
what to work on now and in what order, with reasoning. Encode: importance ≠ urgency ≠ readiness
(deprioritize blocked/undefined/already-worked-around items even if labeled high); protect the
declared primary and do demanding work while fresh; use quick-wins as momentum or breaks, not
day-eaters; name the EF pattern at play and point at the smallest concrete next step. Give a
definitive recommendation with a clear default plus at most one caveat — **not** an even-handed menu.

## 7 — Render the box
Render as a single ASCII box inside one fenced ```text code block (copy-paste-ready, lifted out
whole). This box layout is the STANDARD board output — always use it, not a bare list.

- Header line: `GOALS BOARD — <Weekday YYYY-MM-DD>`. Optional second line for staleness/context
  (e.g. last EOD date, intervening non-work days).
- Layout: a `--- TODAY ---` divider (the tracker block, abbreviated or full per scope), then one
  block per AREA in prio order: an area header line
  `<symbol> <Area title>  [prio <n>] <live N/M (P%) when present> <▲ review due when due>`, then its
  open tasks beneath, one line each:
  `  - <terse task> {tag} ↻ N` — clip, do not wrap. Then the area's linked-thread pointer lines
  (from step 2), prefixed `  » <thread>: <open next item>`. End with an
  `--- OTHER ACTIVE THREADS ---` block for unlinked threads, when any.
- **Tier assignment on the board** expresses each area's **standing priority/value**, NOT today's
  task: prio 1 areas → `★`/`●`, mid → `○`, low/deprioritized → `▽`, stretch → `◇`, `▲` for any
  overdue-review / blocker / duplicate flag. Use `★` sparingly — at most the single clear big-rock
  area, or none. (On `/today`, `★` = the day's declared primary instead.)
- Tier symbols (use only the ones that apply; order as listed):
  - `▸` QUICKSTART — a quick win to knock out first for momentum; leads even the primary.
  - `★` PRIMARY — the declared big-rock / no-exceptions item; the anchor.
  - `●` MUST — comes after the primary is banked.
  - `◐` BREAK — an earned, lower-stakes step-away, not a day-eater.
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
  blank content row between areas.
- **Single-width symbols only.** All tier symbols (`▸ ★ ● ◐ ◇ ○ ▽ ▲`) are single display-width (`▸`
  is U+25B8, the small text-presentation triangle — NOT U+25B6 `▶`, which is emoji-width). Do NOT
  introduce emoji or other double-width glyphs — they silently break alignment even when character
  counts match.

## 8 — Drift footer + offers (absorbed from /current)
Read the `findings` array from the `drift-latest.json` refreshed in step 1b (same run, so counts
agree). If `counts.total > 0`, print a short **drift** block under the box — one line per finding,
grouped (cap ~5 lines; if more, show the count + the top few) — and point at the fixer:
`Resolve drift → /reconcile.` If `counts.total == 0`, omit the block.

## 9 — Footer (mode discovery)
Last line, so modes stay discoverable (bare `/goals` is no longer a menu):

`modes: /today (day door) · new "title" · review · set <id> · link <area> <thread> · done [<id>] · dump · week|long|all`
