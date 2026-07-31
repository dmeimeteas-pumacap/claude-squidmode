# Mode: plan (day-planning coach — pick a style, then route)

`/goals plan` is an executive-functioning coach for structuring the day. It does NOT lead with your
topics or your goal history — it helps you shape time/effort first. It resolves a **planning style**
(a submode), then loads only that submode's file.

## 1 — Resolve the sub-argument
Parse the token after `plan`:

| `/goals plan …` | Submode | Read and follow |
|---|---|---|
| `guided` | structure the day tier-by-tier (effort/importance first) | `modes/plan-guided.md` |
| `brainstorm` | sounding board, no assignments yet | `modes/plan-brainstorm.md` |
| `dump` | brain-dump prose → proposed goals | `modes/dump.md` (+ `reference.md`) |
| `propose` | I propose the day from prior context | `modes/plan-propose.md` |
| `yesterday` \| `carryover` | print yesterday verbatim, then branch (check off / carry over+add / propose) | `modes/plan-yesterday.md` |
| (none) | show the picker (step 2), then dispatch | — |

**Route `yesterday` on the natural phrasings too**, not just the literal token: "based on yesterday",
"carry over from yesterday", "carrying over based on yesterday's", "plan today from yesterday". These
all mean the print-yesterday-first flow, NOT the straight-to-proposal `propose`.

`/goals dump` (top-level) is retired — if the user types it, treat it as `plan dump`.

## 2 — The picker (bare `/goals plan`)
Do NOT read the board or any goal/thread files yet — that anchors old framing. Present a numbered
picker and wait for the choice. (`AskUserQuestion` caps at 4 options and cannot hold this list, so
this is a numbered text menu.)

1. **Guided** — plan around effort/importance before topics/specifics
2. **Brainstorm** — just talk it through, no assignments yet
3. **Dump** — throw everything on your mind at me, we break it down after
4. **Propose** — I tell YOU what I think from prior goals and conversations
5. **Yesterday** — print yesterday verbatim first, then choose: check off / carry over+add / propose
6. **None** — I'll plan later

On the pick, read that submode's file and follow it. On 5 (or any bail), stop cleanly — write nothing.

## 3 — Contextless-first (guided / brainstorm / dump — NOT propose or yesterday)
Every style except `propose` works **contextless first**: take the user's raw input and an initial
stab with no past goals/assumptions surfaced (not blindly — pull in context only where genuinely
pertinent). Reconcile against active goals + open loose ends **after** that first pass, to (a) catch
anything important being dropped and (b) merge with prior goals so continuity/progress is tracked.
`propose` and `yesterday` are the deliberate exceptions — both are context-first by definition
(`yesterday` prints yesterday's context before doing anything else).

**Writes nothing to the goals store directly.** Durable items route through the `new` framework (its
review gate); today-scoped items commit via `today` (the day store). Both only on the user's
confirmation.
