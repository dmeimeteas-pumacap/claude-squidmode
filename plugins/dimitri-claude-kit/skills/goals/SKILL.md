---
name: goals
description: "Goal-setting + day-planning layer above the thread continuity system. Bare `/goals` shows the goal BOARD (all goals, read-only). `/goals plan` is a GUIDED grounding session: broad questions to surface what's on your mind, routing durable items into the `new` goal-creation framework and today-scoped items into `/goals today`. `/goals today` shows today's plan (generating it on first call) and commits it to the standalone task-tracker. Other modes: `/goals new` (capped interview to create one goal), `/goals dump` (rambling prose into proposed goals), `/goals review` (interactive keep/done/drop sweep), `/goals set|link|done`. Use when the user says '/goals', 'set a goal', 'plan my day', 'what should I work on', 'help me figure out what to get done today', 'review my goals', or wants to sort thoughts into goals. NOT for capturing effort state (that is /log), resuming an effort (/catchup), or directly driving the accountability tracker (/task-tracker)."
user-invocable: true
disable-model-invocation: false
argument-hint: "[plan | week | long | all | new \"title\" | dump | review | set <id> | link <goal> <thread> | done <id>]"
---

# Goals Skill (router)

Goal-setting + day-planning above the threads. A **goal** is a top-level entity (its own file) that
relates to many threads via a junction file (`links.tsv`). Threads track an effort's *why*; goals
track *what I'm trying to achieve* across efforts, including non-code/life goals.

This file is a **thin router**. It resolves the mode, then loads ONLY that mode's instructions so a
routine board pull does not drag in every mode's interview logic. Base directory:
`~/.claude/skills/goals`.

Design source of truth: `~/.claude/plans/2026-06-goal-orientation-layer.md`.

## When to invoke

- `/goals` (bare → board), or `/goals <mode>`
- Setting: "set a goal", "I want to achieve X", "new goal"
- Planning: "plan my day", "what should I work on", "help me figure out what to get done today"
- Review: "review my goals", "roll over my unfinished items"

Do **not** trigger for: capturing effort state (`/log`), resuming an effort (`/catchup`),
day-synthesis (`/eod`), or the bare accountability-feed declaration (`/today` — though `/goals plan`
ends by handing off TO it).

## Step 1 — Resolve the date
Use the `currentDate` system-reminder if present; else `date +%Y-%m-%d`. Call this `<DATE>` (every
mode file uses it).

## Step 2 — Resolve the mode, then dispatch

Map the argument to a mode. **Inversion (06-30): bare `/goals` is the BOARD — an action, not a menu.
`plan` is the guided generative day-planning mode (it used to be the board; the board is now bare
`/goals`).**

| Argument | Mode | Read and follow |
|---|---|---|
| (none) | board, broad view (Daily abbreviated + Weekly + Larger) | `modes/board.md` |
| `week` \| `long` \| `all` | board, that horizon | `modes/board.md` |
| `plan` | guided grounding session (routes to `new` + `today`) | `modes/plan.md` |
| `today` | show/generate today's plan, commit to task-tracker | `modes/today.md` |
| `new "title"` | create a goal (capped interview) | `modes/new.md` + `reference.md` |
| `dump` | prose into proposed goals | `modes/dump.md` + `reference.md` |
| `review` | keep/done/drop sweep | `modes/review.md` + `reference.md` |
| `set <id>` \| `link …` \| `done [<id>]` | edit / junction / check-off (bare `done` = interactive sweep across all goals; `done <id>` = single goal) | `modes/manage.md` + `reference.md` |

**Read the mode file(s) with the Read tool before acting.** Modes that write to the store also read
`reference.md` (file format, guardrails, gotchas). `board` is read-only and self-contained — do NOT
load `reference.md` for it (that is the hot path; keep it lean). `plan` and `today` write nothing to
the goals store directly (`plan` routes to `new`/`today`; `today` writes the task-tracker store), so
they do not need `reference.md` either.

**How the argument was given:**
- **Explicit keyword typed** (any value in the table) → the user already decided. Run that mode
  directly. No menu, no confirm. Bare `/goals` runs `board` directly — it is an action now; there is
  no menu.
- **No keyword, free text that *implies* a mode** (e.g. "help me figure out what to do today" reads
  as `plan`; rambling about ambitions reads as `dump`) → state your read in one line and prompt for a
  one-reply confirm ("reply `go` to accept, or name another mode: `plan`, `today`, `dump`, `new`,
  `review`, `board`, `set`, `link`, `done`"). Run only on `go`/`yes`/a restated mode.

Mode discovery lives in the board footer (a one-line list of modes), not a standalone menu.

## Step 3 — Maintain `last_touched`
Any mode that writes a goal file bumps its `last_touched` to `<DATE>` (see `reference.md`). `board`,
`plan`, and `today` write nothing to the goals store (`today` writes the task-tracker store). No
INDEX is maintained.
