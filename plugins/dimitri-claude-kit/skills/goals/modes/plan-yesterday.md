# Submode: plan yesterday (print yesterday, then branch)

Context-FIRST style, like `propose` — the exception to `plan.md`'s contextless-first rule. Fires
when the user asks to plan today **based on yesterday** / carry over from yesterday. The distinction
from `propose`: this submode does NOT lead with a proposal. It prints yesterday verbatim FIRST, then
lets the user choose what happens next (one of which is "now propose", which reuses `propose`).

## 1 — Print yesterday's goals VERBATIM (both sources, labeled) — do this FIRST

Before any proposing, branching, or synthesis, print two clearly-labeled blocks, **verbatim** (do not
reorder, summarize, or editorialize the items — the point is to see yesterday exactly as it was):

### A) Yesterday's committed plan (shown as the OneNote view)
**Display source: the OneNote-paste handoff file `~/.claude/eod/plan-latest.txt`** — the exact
numbered, glyph-tagged, `[done]`-marked text that was pasted into OneNote (notebook "Master Manual",
section "Task Tracker", subpage `M/d/yyyy`). Print it **verbatim**. This is what the user visually
tracks against, so the numbering is what they check off by.

The underlying store is the day store `~/.claude/accountability/today.md`; `plan-latest.txt` is its
OneNote mirror **when this install mirrors at all** (mirroring is optional — if `plan-latest.txt` is
absent or stale, print the store itself instead and skip every OneNote-specific step below). There is **no history archive** (see Gotchas), so recoverability depends on whether
today's plan has been generated yet:
- **If the files still read YESTERDAY's date** (`plan-latest.txt` header `Daily Plan - M/d/yyyy`,
  `today.md` header `# Today's Intent - <date>`; today's plan not yet generated) → they still hold
  yesterday's committed plan. Print `plan-latest.txt` verbatim.
- **If they already read today's date** (a `/today` run overwrote them) → yesterday's plan is no
  longer stored. Reconstruct from the EOD `## What moved today` section and **label it "reconstructed
  from EOD (tracker/OneNote already overwritten)"**.

**Sync note (write-only wiring).** The OneNote paste path is one-directional — Claude writes/re-pastes,
it cannot read back the user's live ticks. This is safe ONLY because the user checks items off solely
by asking Claude (never a raw OneNote-only tick), so `today.md` stays
the source of truth and `plan-latest.txt` mirrors it. In option A, **verify the two agree** (each
`[done]` ↔ an `[x]`) and flag any drift; if they diverge, the user made an out-of-band OneNote tick and
you must ask which side is correct before checking anything.

### B) EOD tomorrow's-priorities (queued FOR today)
Source: `~/.claude/session-notes/eod-latest.md`, the `## Tomorrow's priorities` section. This is the
forward-looking list written at end of yesterday for today. Print it verbatim.

If either source is missing or unreadable, print the one available and name the gap in one line.
**Never fabricate a plan or invent items.**

## 2 — Offer the three branches (A / B / C)

After the two blocks are printed, ask the user which they want via `AskUserQuestion` (**multiSelect** —
they may want more than one). If more than one is picked, process in **A → B → C** order (clear the
decks, then carry over, then propose over what remains). If the user dismisses or picks nothing, stop
cleanly — **write nothing**.

- **A — Check stray things off.** If a OneNote mirror exists, first run the sync check (block A
  above); if the store and mirror diverge, resolve that before ticking. Then let the user check off
  **by the printed number** from the verbatim list. Confirm the exact set before checking anything
  (never auto-check). Route each: day-store items → `modes/today.md` step-5 tick (incl. its goals.md
  write-back); thread `## Next` items → the `/log done` checkoff path (log skill mode 3g). After
  ticking, refresh any optional mirror per `modes/today.md` step 4. Report what was ticked.
- **B — Carry over + add.** The user names which yesterday items to carry into today and any brand-new
  goals to add. Commit the chosen day set to today via `modes/today.md` step 3. New DURABLE goals
  route through the `new` framework (`modes/new.md`, its review gate); today-only items just commit
  to the day store. Manual-first: commit only what the user named.
- **C — Propose from what I see.** Delegate to `modes/plan-propose.md`, **entering at its step 2**
  (the proposal core) — the review-yesterday gate is already satisfied by this flow, so do NOT
  re-prompt it (that would loop). A definitive proposed day built from the printed yesterday context
  (plus the board / linked thread `## Next`); propose owns its own one-reply confirm before committing.

## 3 — Write behavior
Writes nothing until a branch is chosen and confirmed. A and B may both write (A ticks off; B commits
today). C hands to `propose`, which owns its own confirm→commit. Bumps no goal-file `last_touched`
directly (commits happen in the delegated modes). Manual-first throughout.

## Gotchas
- **No day-store history.** `~/.claude/accountability/today.md` holds ONE day and is overwritten on
  the next `/today` declare. If today's plan was already generated before this submode runs, yesterday's
  raw committed plan is gone — fall back to the EOD `## What moved today` reconstruction and label it.
  (If this loss becomes a recurring annoyance, the real fix is snapshotting `today.md` to a dated
  archive before overwrite — out of scope for this submode; raise it as its own change.)
- Print verbatim means verbatim: resist the pull to "clean up" yesterday's wording. The user asked to
  see yesterday as-is so nothing silently changes shape between days.
