# Mode: today (`/goals today`)

Show **today's plan**, generating it the first time it is asked for. This is the bridge between the
goals layer and the standalone task-tracker: today's plan lives in ONE place, the task-tracker store
`~/.claude/accountability/today.md`. `/goals today` reads and writes *there* — it does not keep a
separate copy.

This mode is invoked two ways: directly by the user (`/goals today`), and as the closing step of
`/goals plan` (which passes it a freshly distilled primary + musts).

## 1 — Read the store
```powershell
& "$env:USERPROFILE\.claude\accountability\task-tracker.ps1" show
```
- **A plan exists** (show prints the numbered list) → relay it. Done. Add the next-action line
  (smallest concrete step on the primary) if useful, using the board's sequencing principles
  (importance ≠ urgency ≠ readiness; protect the primary; demanding work while fresh).
  - **Render with tier symbols, not a flat list.** Reuse the `board.md` step-7 legend
    (`▸ ★ ● ◐ ◇ ○ ▽ ▲`): the declared primary is `★`, a `▸` QUICKSTART is a quick win to knock out
    first (it sorts ahead of the primary), then assign each remaining item a symbol by its
    **impact / significance / priority** so the day shows a value gradient (e.g. a hard must → `●`,
    secondary/variety → `○`, a deprioritized or token-gated item → `▽`, an earned tooling break →
    `◐`, a blocker/flag → `▲`). Keep the tracker's item numbers — they are what `task-tracker done
    <n>` ticks.
  - **Print a one-line legend** below the list covering the symbols actually used, e.g.
    `legend: ▸ quickstart · ★ primary · ● must · ○ secondary · ◐ break · ▽ deprioritized/gated · ▲ flag`.
- **No plan set** (show says "no plan set") → go to step 2 to make one.

## 2 — Generate today's plan (only when none is set)
If invoked from `/goals plan`, you already have the distilled primary + musts — skip straight to
step 3. Otherwise, run a SHORT generation grounded in what's tracked (this is the lighter,
board-aware counterpart to `plan`'s from-scratch session):
- Glance at the board (active goals' `### Daily` + linked thread `## Next`; see `board.md`'s scoped
  read) and the latest EOD digest, and propose a PRIMARY + a few musts for today.
- Offer the proposal for a one-reply confirm/edit (manual-first — do not declare what the user did
  not pick). If the user would rather generate from scratch, send them to `/goals plan`.

## 3 — Commit to the tracker
Write the confirmed plan via the CLI (single shared store, no second copy). **Prefix each must with
its assigned tier glyph** so the gradient you rendered in step 1 is stored and the standalone CLI
re-renders it (the primary is always `★`, so it needs no prefix; a must with no prefix defaults to
`●`):
```powershell
& "$env:USERPROFILE\.claude\accountability\task-tracker.ps1" declare "<primary>" "▸ <quickstart>" "● <must>" "○ <must>" "▽ <must>"
```
Then relay the resulting plan. Mention the ambient feed widget reflects it within ~10s if running;
offer `task-tracker feed` only if the user says it is missing.

**Writes nothing to the goals store** — the only goals/tracker write is the task-tracker `declare`
above, after confirmation. (The optional OneNote mirror in step 4 writes only its own handoff file.)

## 4 — Mirror to OneNote (best-effort)
Whenever a plan exists for today (just shown in step 1, or just committed in step 3), mirror it into
the same OneNote daily page the EOD uses, as the **"Daily Plan"** block.

Render the plan as the tracker shows it, **keeping the tier glyphs** (`▸ ★ ● ○ ◐ ◇ ▽ ▲`). The COM
paste path preserves Unicode (unlike the clipboard path the eod ASCII rule guards against), so the
glyphs render. First line is the header `Daily Plan - M/d/yyyy` (today's date, no zero-pad). Then one
line per tracked item at a 4-space indent, keeping the tracker's item number and its tier glyph.
Example line: `    ★ 1. Ship the v0.1.3 install re-test`.
**Always end the block with a legend line** (a blank line, then the same one-line legend
`task-tracker show` prints — covering only the glyphs actually used) so the pasted plan is
self-explanatory on its own, e.g. `    legend: ▸ quickstart · ★ primary · ● must · ○ step-back · ▽ backburner`.
Write the handoff file as **UTF-8** so the glyphs survive the round-trip.

Write that text (UTF-8) to `~/.claude/eod/plan-latest.txt`, then trigger the paste task:
```powershell
Start-ScheduledTask -TaskName "ClaudeOneNotePaste-Plan"
```
Same de-elevation rationale as the eod skill's Step 4c: the `ClaudeOneNotePaste-Plan` task runs at
Limited (non-elevated) integrity, so the paste works from elevated interactive sessions. It replaces
any earlier plan block for the day on today's `M/d/yyyy` subpage under "Dimitri General" (the EOD
block sits below it). Outcome is appended to `~/.claude/eod/paste-last.log`.

**Best-effort, never fatal**: do not block on the task; a paste failure leaves the tracker (the
source of truth) untouched. Skip entirely if no plan is set for today.
