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
    (`★ ● ◐ ◇ ○ ▽ ▲`): the declared primary is `★`, then assign each remaining item a symbol by its
    **impact / significance / priority** so the day shows a value gradient (e.g. a hard must → `●`,
    secondary/variety → `○`, a deprioritized or token-gated item → `▽`, an earned tooling break →
    `◐`, a blocker/flag → `▲`). Keep the tracker's item numbers — they are what `task-tracker done
    <n>` ticks.
  - **Print a one-line legend** below the list covering the symbols actually used, e.g.
    `legend: ★ primary · ● must · ○ secondary · ◐ break · ▽ deprioritized/gated · ▲ flag`.
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
& "$env:USERPROFILE\.claude\accountability\task-tracker.ps1" declare "<primary>" "● <must>" "○ <must>" "▽ <must>"
```
Then relay the resulting plan. Mention the ambient feed widget reflects it within ~10s if running;
offer `task-tracker feed` only if the user says it is missing.

**Writes nothing to the goals store** — the only write is the task-tracker `declare` above, after
confirmation.
