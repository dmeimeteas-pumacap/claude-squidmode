---
name: reconcile
description: "Continuity/cleanliness reconciler with two lanes. SYNC lane: detects drift across the ~/.claude stores (goals.md areas, threads, INDEX, links.tsv, tracker sidecar) via the shared detect-drift.ps1 engine and resolves it in-session by delegating to /log and /goals modes; deterministic INDEX fixes apply directly. STATUS-UPDATE lane (absorbed from the retired /update-statuses, 2026-07-31): an interactive digest-driven walk-through truing records to reality — tick done thread/goal items, route uncaptured work, recap. Bare /reconcile asks which lane; `/reconcile sync` or `/reconcile status` skips the question. Use when the user says '/reconcile', 'reconcile my state', 'clean up drift', 'fix the stale state', 'sync threads and goals', 'update my statuses', 'check off what's done', 'true up my records', 'run through my threads', or after the session-start banner / mid-session staleness line reports drift. Companion to the passive freshness layer (scheduled headless detector + prompt-time staleness hook) — that layer detects and surfaces; THIS skill writes. NOT /deepclean (filesystem janitor), /log (single-effort capture), /eod (day synthesis)."
user-invocable: true
disable-model-invocation: false
argument-hint: "[sync [<finding-kind>|<slug>] | status]"
---

# Reconcile Skill (two lanes: sync + status-update)

Keeps the `~/.claude` continuity stores honest. The deterministic detector
(`~/.claude/janitor/detect-drift.ps1`) finds drift and writes `janitor/drift-latest.json`; this
skill reads that report, layers judgment, and **applies fixes by delegating to the existing `/log`
and `/goals` lifecycle modes** — it never hand-edits append-only thread/goal sections.

Store model (2026-07-31): goals live in the single-file area store `~/.claude/goals/goals.md`
(areas keyed by `id:`; tasks with `{timeliness}` tags + `↻ N` rollovers — format in
`skills/goals/reference.md`). Threads are MEMORY, decoupled; the day's plan is the tracker store +
its `accountability/today-goalmap.tsv` sidecar (tracker item ↔ area task).

## Step 0 — Resolve the lane

- `/reconcile sync [<kind>|<slug>]` → SYNC lane. `/reconcile status` → STATUS-UPDATE lane.
- Bare `/reconcile` (or ambiguous phrasing) → ask once (AskUserQuestion, single-select):
  **"Synchronization check (drift engine → fix findings) or status update (walk through what you
  actually did → true up the records)?"** Options: `Sync check` / `Status update` / `Both (sync
  first)`.
- Phrasing that clearly names a lane skips the question: "clean up drift" / "fix stale state" /
  "sync threads and goals" → sync; "update my statuses" / "check off what's done" / "true up my
  records" / end-of-day phrasing → status.

Both lanes are live-session only where popups are involved; never run the interactive parts
headless.

---

# SYNC lane (detector-driven)

## Guardrails
- **Delegate for canonical stores; never hand-edit append-only sections.** Thread `## Decisions` /
  `## Log` are append-only; `## Where I left off` / `## Next` and goals.md tasks are owned by their
  modes. Apply changes ONLY via `/log` (`done|close|pause|fullclose`, or a normal capture) and
  `/goals` (`done|set|link|review`).
- **INDEX is derived — fixing it directly is allowed.** Regenerate affected row(s) from the thread
  file(s); announce each fix with the before/after row.
- **Confirm every judgment call once.** Deterministic INDEX regenerations apply + announce;
  anything touching thread/goal content gets a single one-reply confirm before delegating.
- **Never auto-rewrite narrative.** A `snapshot_trails_live` finding resolves by offering a normal
  `/log` capture, not a direct edit.

## Process
### Step 1 — Refresh + read the report
```
powershell -NoProfile -File "%USERPROFILE%\.claude\janitor\detect-drift.ps1" -ClaudeDir "%USERPROFILE%\.claude" -Quiet
```
(Plugin install: the engine ships beside this skill's hooks — if the `janitor\` copy is absent, run
`${CLAUDE_PLUGIN_ROOT}/scripts/detect-drift.ps1` with the same `-ClaudeDir` argument. Artifacts
always land in `~/.claude/janitor/` either way.)
(The scheduled task keeps this fresh in the background, but re-run anyway — it is cheap and
guarantees the report reflects this second.) Read `~/.claude/janitor/drift-latest.json`. If
`counts.total == 0` and step 2 adds nothing, say "no drift — stores are clean" and stop. If a
`<kind>`/`<slug>` arg was given, filter to it.

### Step 2 — Layer judgment (model-side checks the detector leaves open)
Using live conversation + file context, additionally look for the judgment-only classes:
- `next_item_looks_done` — a thread `## Next` or goals.md task done in reality but still `[ ]`.
  When a fresh `eod-latest.md` digest exists, use its "What moved" / Did lines as the evidence
  source (never invent completions; digest-in-progress items are NOT candidates).
- `tracker_goal_lag` — a tracker item ticked `[x]` in `accountability/today.md` whose mapped
  goals.md task (via `today-goalmap.tsv`) is still `[ ]`. Deterministic when the sidecar row
  exists; confirm slice-vs-whole before flipping (a ticked SLICE leaves the parent task open).
- `thread_goal_divergence` — a thread `## Next` pointer and a goals.md task that describe the same
  work but disagree (one done, one open; or reworded apart). Surface + confirm; align by delegating
  (`/log done` / `/goals done`) — NEVER auto-sync, the stores are deliberately decoupled.
- `possible_redundancy` — two areas/threads covering one effort.
- `cross_thread_contradiction` — the cross-thread pass: for each active thread, take its open
  `## Next` items + questions in `## Where I left off`, and scan the OTHER active threads'
  `## Decisions` (and recent `## Log` Did lines) for entries that answer or contradict them. Check
  `related:` and same-`project` threads first; widen only if the scoped pass found something. Emit
  a finding naming both threads, the open item, and the deciding entry, quoting each.
Do not invent drift — cite the file text.

### Step 3 — Present, grouped and tight
**Auto-fix (INDEX)** first, then **confirm (content)**. One line each, most-severe first. The user
is info-overload-sensitive — keep it scannable; do not paste file bodies.

### Step 4 — Apply, by class
- **`index_*` (auto-fix, derived):** regenerate the affected INDEX row(s) from the thread file(s) —
  row format `| [[slug]] | project | prio | MM-DD(last_touched) | first-sentence-of-Where-I-left-off |`.
  `malformed_index_row` → split the merged line; `index_wrong_table` → move the row. Apply +
  announce (show before/after).
- **`snapshot_trails_live`:** offer a normal `/log` capture on the named thread. Confirm, delegate.
- **`status_claims_done`:** confirm actually finished → `/log close`/`fullclose`; else suggest a
  `## Next` item via a normal capture.
- **`next_item_looks_done`:** confirm → `/log done <slug>` or `/goals done <id>`.
- **`tracker_goal_lag`:** confirm whole-task (not slice) → flip the goals.md task via `/goals done`.
- **`thread_goal_divergence`:** confirm which side is truth → delegate the lagging side's tick;
  never copy text between stores.
- **`over_rolled_goal`:** surface for `/goals review` (re-scope, re-time, or drop — not a re-roll).
- **`goal_area_unkeyed`:** add the missing `id:` metadata line (confirm the intended id).
- **`possible_redundancy`:** propose a merge/link → `/goals link` / `/log merge` / a close; always
  confirm.
- **`cross_thread_contradiction`:** confirm the deciding entry settles it (quote both sides) →
  `/log done <slug>` or a capture closing the question with `see [[deciding-slug]]`. Link, never
  copy.
- **`live_read_failed`:** report the area + the precondition (e.g. the live_progress command only
  reports correctly on a specific git branch); the user's to fix.
- **`links_goal_orphan` / `links_thread_orphan`:** confirm truly gone (not renamed) → remove the
  dead edge from `links.tsv` (filter-rewrite — tabs mangle under line edits); if renamed, fix the
  target.
- **`memory_index_drift`:** missing file → remove the stale pointer; unpointed file → add a
  one-line pointer. Confirm direction.

### Step 5 — Re-emit + report
Re-run `detect-drift.ps1 -Quiet` so the report (and the banner/hook count) reflects the fixes.
Report applied vs deferred.

---

# STATUS-UPDATE lane (absorbed from /update-statuses)

An interactive walk-through truing the records to what actually happened — mid-day after a burst of
work, or an end-of-day close. **Consumer of the `/eod` digest, never a re-scanner of raw
transcripts.**

### Step 0 — Digest freshness
Read `~/.claude/session-notes/eod-latest.md`. Absent → run `/eod` to generate it. Stale (thread
files or non-home-project JSONLs newer than it) → refresh via `/eod`. Nothing changed since the
last digest → warn once ("little to reconcile — run anyway?"), let the user abort. The digest is
the prep-sheet for all stations.

### Station 1 — Done check-offs (threads)
Cross-reference open thread `## Next` items against the digest + `## Log` Did lines. Candidates
only where evidence supports it. Present via multiSelect popup (+ `— none done —` sentinel; ≤4
options/question, ≤4 questions/call, split rather than truncate). Ticked → `/log done`'s tick
(flip + `last_touched` bump + INDEX row).

### Station 2 — Goal done-pass (areas)
Same for goals.md tasks — prioritized by the two deterministic lags: `tracker_goal_lag` (sidecar
rows ticked in the tracker but open in goals.md) and linked-thread `[x]` vs area-task `[ ]`. Ticked
→ `/goals done`'s flip. **Done-only** — never drop/roll/re-scope here (that is `/goals review`).

### Station 3 — Uncaptured-work routing
From the digest's decisions/in-progress + the live session, identify work/decisions not reflected
in any store. Cluster; per cluster offer: `/log` to a thread / new thread / memory / drop
(conscious, noted). Execute the chosen route. Everything already captured → say so, move on.

### Station 4 — Recap (chat-only)
What got ticked/routed, which stations were empty, and the 1–3 most important carry-forwards (one
line each, smallest next step). Do NOT set the day's plan — that is `/today`.

Guardrails: never invent completions; an empty station is a valid result; reuse `/log done` +
`/goals done` mechanics exactly, never fork them.

---

# Passive freshness layer (detection without invocation)

The goal: any session is always working against the newest state (git, threads, goals, other
conversations) WITHOUT the user remembering to check. Three pieces, built 2026-07-31:

1. **On-demand headless detector refresh.** The prompt-time hook (piece 3) checks
   `drift-latest.json`'s age; when older than ~10 minutes it spawns ONE detached hidden
   `detect-drift.ps1 -Quiet` run (fire-and-forget, report-only, writes only the janitor artifacts).
   So the detector runs only while Claude is actually in use — nothing polls in the background when
   idle. (The earlier `ClaudeDriftDetect` 15-min scheduled task was replaced by this on 2026-07-31.)
2. **Session-start banner** (existing) surfaces the drift count when a session opens.
3. **Prompt-time staleness hook.** A `UserPromptSubmit` hook (`janitor/staleness-check.ps1`)
   injects a one-line context note into the running conversation when (a) `drift-latest.json` has
   findings, or (b) a store file (threads/goals.md/INDEX/today.md) changed after the session
   started — i.e. another conversation moved state mid-session. The note names what changed and
   points here. It injects at most once per change-set (stamped in `janitor/staleness-seen.json`
   per session) so it nags, but only once per staleness.

The passive layer NEVER writes stores — it detects and surfaces; resolution stays in-session here
(confirm-gated), except derived INDEX fixes which this skill auto-applies when run. When the hook's
note appears mid-conversation, re-read the named store file(s) before answering anything that
depends on them — that is the "aggressively current" contract.

## Versioning
- New cleanliness categories: add a finding `kind` in `detect-drift.ps1` + a Step-4 handling line.
- If the detector and this skill disagree on a `kind`, the detector's schema wins; update this file.
- History: `/update-statuses` folded in 2026-07-31 (its stations 1–3+5 became the STATUS lane;
  station 4 quick-wins dropped — the board surfaces near-done items). Trigger phrases migrated to
  the description above.
