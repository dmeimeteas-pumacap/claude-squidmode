# Mode: today (`/today`, or legacy `/goals today`)

Show **today's plan**, generating it the first time it is asked for. This is the day door of the
two-door model: today's plan lives in ONE place, the plain-markdown store
`~/.claude/accountability/today.md`, owned and edited directly by this mode (the old standalone CLI
was scrapped 2026-07-31 — no external program involved). The picks come FROM the areas store
`~/.claude/goals/goals.md` (see `reference.md`), and ticking a picked task **writes back** to its
area's list.

Invoked three ways: directly (`/today`), as the closing step of the plan submodes (which pass a
freshly distilled primary + musts), and conversationally ("add a task", "check off #3", "declare my
day" — the verbs in step 5).

## Store format (`accountability/today.md`)

```markdown
# Today's Intent - YYYY-MM-DD

## Primary
- [ ] {★} <the day's primary>

## Musts
- [ ] {▸} <task>
- [ ] {●} <task>
  - [ ] {●} <sub-item>        (4-space-indented children nest under the item above)
```

- One `{glyph}` per item (the board legend: `▸ ★ ● ◐ ◇ ○ ▽ ▲`); the primary is always `{★}`.
- **Item numbers are positional**: 1 = the Primary item, then every checkbox line in file order
  (sub-items get their own numbers). Always render the numbers — they are what "done #n" ticks.
- The store may carry extra sections (Focus window, Status) from earlier tooling — preserve them if
  present, never require them.
- **Empty sections render honestly:** a plan with a primary but empty `## Musts` shows just the
  primary + `(no musts declared — "add <task>" appends one)`; never invent placeholder items and
  never treat an empty section as a broken store.
- The store holds ONE day. Setting a new day's plan overwrites it (no history archive;
  `plan-yesterday` documents the recovery path).

## 1 — Read the store
Read `~/.claude/accountability/today.md`.
- **A plan exists for today** (header date = `<DATE>`) → relay it: numbered list with tier glyphs,
  strikethrough/`[x]` state, and a one-line legend covering the glyphs used. Add the next-action
  line (smallest concrete step on the primary) if useful, using the board's sequencing principles
  (importance ≠ urgency ≠ readiness; protect the primary; demanding work while fresh).
- **No plan / stale date** → go to step 2 to make one.

## 2 — Generate today's plan (only when none is set)
If invoked from a plan submode, you already have the distilled primary + musts — skip to step 3.
Otherwise run the **pick**, the coach loop (this section IS the spec — the author-side plan file it
came from does not ship):

1. **Read the areas.** `goals.md` open tasks, prio order, with timeliness tags (`{deadline:…}` due
   soon and `{this-week}` first), `↻ N` rollovers, and any live count from the last
   `drift-latest.json` if fresh (do not block plan-making on a live read). Glance at the latest EOD
   digest for carry-over context.
2. **Propose 3–5 picks to hammer today** — a target, not a cap. A pick is a task from an area — or
   a **slice** of a big one (name the slice concretely; completion happens at the slice level, the
   parent task stays open). A genuine loose one-off may join unlinked; do not force it under an
   area. **Sub-items are a first-class option** — offer nesting whenever a pick has natural parts
   (breaking a pick into checkable steps under it often beats adding more top-level picks), and
   preserve any parent/child shape the user gives. **Sub-items do NOT count as additional picks** —
   nesting under a pick is structure, and the count/budget attach to top-level picks only. Exception worth a *light* comment: when a
   sub-item is clearly its own independent piece of work (different outcome, could be done on a
   different day), observe once that it might belong as its own task or under a different area —
   an offer about how the tasks are laid out, not a correction. Never restructure uninvited, never
   repeat the observation.
3. **Elicit weights, coach-style.** Each pick gets light / medium / heavy = 1 / 2 / 3. Propose what
   looks heavier and probe ("how does this actually feel / how long really") — cold self-assignment
   underweights to pile more on.
4. **Soft budget ~5 points — FEEDBACK ONLY, never enforcement.** Over budget → say so once, with
   reality attached: fixed obligations, the midday-lull energy pattern, rollover counts (a task at
   ↻ 3+ needs a smaller slice, not another re-roll). Then commit **exactly what the user chose** —
   never trim, refuse, or re-ask. The budget exists to make over-commitment visible, not to gate
   the plan; a user who takes 8 points with eyes open has been coached, and that is the whole job.
5. Offer the result for a one-reply confirm/edit (manual-first — do not declare what the user did
   not pick).

## 3 — Commit to the store (+ the goal-map sidecar)
Write the confirmed plan to `accountability/today.md` in the store format above (UTF-8, no BOM —
the glyphs must survive). Preserve any parent/child nesting the user gives.

**Then write the goal-map sidecar** `~/.claude/accountability/today-goalmap.tsv` (TAB-separated,
UTF-8 no BOM, overwritten with each new plan):
```
<item-n>	<area-id>	<verbatim goals.md task line text (trimmed, no checkbox)>
```
One row per pick that came from an area (slices map to their parent task; unlinked one-offs get no
row). This sidecar is what makes the tick write-back (step 5) and `/reconcile`'s tracker-vs-goals
check deterministic.

Then relay the plan back, numbered, with the legend.

## 4 — Optional mirrors (a config boolean — NEVER probed, NEVER required)
Gate: the `onenotePlanMirror` boolean in `~/.claude/accountability/config.json` (kit default
`false`; flipping it is a one-line config edit the user just asks for). No runtime detection, no
scheduled-task probing — read the flag alongside the store, that's it.
- **`true`** → mirror to OneNote: render the plan (header `Daily Plan - M/d/yyyy` from the STORE
  date, 4-space-indented numbered items keeping glyphs, ` [done]` on ticked items, closing legend
  line) to `~/.claude/eod/plan-latest.txt` (UTF-8) and `Start-ScheduledTask
  ClaudeOneNotePaste-Plan`. Refresh whenever the plan is set or ticked. Best-effort, never fatal.
- **`false` / absent / config unreadable** → skip silently — no warning, no setup prompt.
The mirror is interim tooling slated for retirement once the EF hub exists; new mirror kinds get
their own boolean here, not detection logic.

## 5 — Verbs + the tick WRITE-BACK
Conversational verbs, all direct edits to the store:
- **"done #n" / "check off …"** → flip that item's `- [ ]` → `- [x]`. Then look up item `n` in
  `today-goalmap.tsv`; if mapped AND the tick completes the actual goals.md task (not just a slice —
  ask when ambiguous, default = slice, parent stays open), flip that task in
  `~/.claude/goals/goals.md` (checkbox only, never task text). Refresh any step-4 mirror.
- **"undo #n"** → flip back `[x]` → `[ ]` (goals.md write-back reverts only if it was flipped by
  this item's tick).
- **"add …"** → append a `- [ ] {●} <task>` line under Musts (offer to link it to an area; if
  linked, append a sidecar row).
- Manual-first: record only what the user declares; do not invent musts or a primary.

## Gotchas
- The sidecar matches goals.md tasks by verbatim line text — if a task is reworded in goals.md
  mid-day, the write-back match fails; report it and flip by hand instead of guessing.
- PowerShell `-Encoding utf8` writes a BOM; use the Edit/Write tools for store edits.
- Item numbers shift when items are added — always re-render the numbered list after any edit so
  the user ticks against current numbers.
- Never treat an external mirror (e.g. OneNote) as a tick source — the store is the only truth.
