---
name: today
description: "The DAY door of the two-door model — today's plan and nothing else: pick 3-5 tasks from the /goals areas to hammer today (a target not a cap; coach-elicited light/med/heavy weights, soft ~5-point budget that gives feedback once and never blocks; sub-items nest without counting as extra picks), show the plan, tick items off (ticks write back to the area's task list in goals.md), add a task. Store = the plain-markdown file ~/.claude/accountability/today.md, owned directly by this skill — no external program. Optional mirrors (e.g. OneNote) are gated by a config boolean (accountability/config.json onenotePlanMirror, kit default false), never probed or required. Use when the user says '/today', 'show today', 'what's my plan today', 'plan my day', 'track my day', 'add a task', 'check off', 'done #n', 'declare my day', or 'set today's intent'. NOT for standing areas/goals maintenance (/goals — the AREAS door), capturing effort state (/log), or day synthesis (/eod)."
user-invocable: true
disable-model-invocation: false
argument-hint: "[show | done <n> | undone <n> | add \"<task>\"]"
---

# Today (the DAY door)

One place for "what am I doing today and how am I tracking." Behavior lives in the goals skill's
`today` mode file so the two doors share one store discipline — read
`~/.claude/skills/goals/modes/today.md` with the Read tool and follow it verbatim.

Do this now:
1. Resolve `<DATE>` (the `currentDate` system-reminder if present, else `date +%Y-%m-%d`).
2. Read `~/.claude/skills/goals/modes/today.md` and follow it. Treat any text after `/today` as the
   trailing argument (`show` default; `done <n>` / `undone <n>` / `add` are its step-5 verbs).

Do not reimplement the logic here. The single source of truth is `modes/today.md`.
