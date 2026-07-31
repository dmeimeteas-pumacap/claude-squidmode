---
name: goals
description: "The AREAS door of the two-door model — the persistent action/planning store (~/.claude/goals/goals.md): every area (= goal: a tag + optional north-star + its own task list) and the tasks under it. Threads stay separate MEMORY (/log, /catchup). Bare `/goals` shows the BOARD — areas + tasks + live counts + today's tracker summary + open thread pointers + drift footer (this absorbed the retired /current, so it IS the status report). Use for: '/goals', 'set a goal', 'new goal', 'review my goals', 'check off a goal task', 'where's my work at', 'current status', 'progress report', 'status of everything', or sorting rambling thoughts into areas ('dump'). Modes: `new \"title\"` (capped interview), `review` (weekly keep/done/drop sweep with rollover), `set <id>` / `link <area> <thread>` / `done [<id>]`, `plan [guided|brainstorm|dump|propose|yesterday]` (day-planning coach styles — these END by handing to /today), `week|long|all` (board scopes). NOT for: the day's plan or ticking today's tasks (/today — the DAY door), capturing effort state (/log), resuming an effort (/catchup)."
user-invocable: true
disable-model-invocation: false
argument-hint: "[week | long | all | new \"title\" | review | set <id> | link <area> <thread> | done [<id>] | plan [guided|brainstorm|dump|propose|yesterday]]"
---

# Goals Skill (router — the AREAS door)

The persistent action/planning layer. An **area** (= a goal) is a `## ` section of the single store
`~/.claude/goals/goals.md`: a tag + optional north-star + its own list of actionable tasks. Tasks
live here, NOT in threads — threads are memory (`/log`/`/catchup`); `/reconcile` cross-checks the
two. The DAY door is `/today` (pick tasks to hammer, weights, tick); the two doors stay distinct by
design.

This file is a **thin router**. It resolves the mode, then loads ONLY that mode's instructions so a
routine board pull does not drag in every mode's interview logic. Base directory:
`~/.claude/skills/goals`.

Design source of truth: `~/.claude/plans/2026-07-goal-tracking-redesign.md` (the 2026-07 area-model
redesign; supersedes `2026-06-goal-orientation-layer.md`).

## When to invoke

- `/goals` (bare → board), or `/goals <mode>`
- Setting: "set a goal", "I want to achieve X", "new goal"
- Status: "where's my work at", "current status", "progress report" (the board is the status report)
- Review: "review my goals", "roll over my unfinished items"

Do **not** trigger for: the day's plan / today's tasks (`/today` — including "plan my day", which
routes there or through `plan`'s styles ending at `/today`), capturing effort state (`/log`),
resuming an effort (`/catchup`), day-synthesis (`/eod`).

## Step 1 — Resolve the date
Use the `currentDate` system-reminder if present; else `date +%Y-%m-%d`. Call this `<DATE>` (every
mode file uses it).

## Step 2 — Resolve the mode, then dispatch

| Argument | Mode | Read and follow |
|---|---|---|
| (none) | board, broad view (today abbreviated + all areas) | `modes/board.md` |
| `week` \| `long` \| `all` | board, that scope | `modes/board.md` |
| `plan` [`guided`\|`brainstorm`\|`dump`\|`propose`\|`yesterday`] | day-planning coach; bare shows the style picker; all styles END by handing to `/today` | `modes/plan.md` (then the submode file) |
| `yesterday` \| `carryover` | print yesterday verbatim, then branch | `modes/plan-yesterday.md` |
| `propose` | Claude proposes the day; gated by "review yesterday first?" | `modes/plan-propose.md` |
| `today` | LEGACY alias — the day door moved to `/today` | `modes/today.md` |
| `new "title"` | create an area (capped interview) | `modes/new.md` + `reference.md` |
| `dump` | treated as `plan dump` (prose → proposed areas/tasks) | `modes/dump.md` + `reference.md` |
| `review` | weekly keep/done/drop sweep | `modes/review.md` + `reference.md` |
| `set <id>` \| `link …` \| `done [<id>]` | edit / junction / check-off (bare `done` = interactive sweep across all areas) | `modes/manage.md` + `reference.md` |

**Read the mode file(s) with the Read tool before acting.** Modes that write the store also read
`reference.md` (store format, guardrails, gotchas). `board` is read-only and self-contained — do NOT
load `reference.md` for it (hot path; keep it lean). `plan` and its non-dump submodes write nothing
to the goals store (they hand off to `/today`); `dump` reads `reference.md` (it can create areas).

**How the argument was given:**
- **Explicit keyword typed** → the user already decided. Run that mode directly. No menu, no
  confirm. Bare `/goals` runs `board` directly.
- **No keyword, free text that *implies* a mode** (e.g. "review my goals" reads as `review`;
  rambling about ambitions reads as `dump`; **"based on yesterday" / "carry over from yesterday"
  reads as `yesterday`**; "what should I work on / plan my day" reads as `plan` — offer `/today`
  first if a plan already exists) → state your read in one line and prompt for a one-reply confirm.
  Run only on `go`/`yes`/a restated mode.

Mode discovery lives in the board footer (a one-line list of modes), not a standalone menu.

## Step 3 — Store hygiene
Any mode that writes `goals.md` follows `reference.md`'s format exactly (metadata line keyed by
`id:`, `↻ N` spacing, timeliness tags). No INDEX is maintained; the board is the dashboard.
