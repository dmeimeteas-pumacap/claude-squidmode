---
name: deepclean
description: "Filesystem-level janitor for ~/.claude — the deletion/move/merge/archive layer the /reconcile skill deliberately never touches. Detects and (after you confirm) removes superseded plans, promoted-scaffold cruft, memory-index drift, past-due dated files, dev leftovers, and doc-vs-code drift. Use when the user says '/deepclean', 'deep clean the setup', 'sweep the stale files', 'audit and clean ~/.claude', 'what can we delete', or wants a periodic systemwide tidy. Manual + propose-then-confirm only — NEVER headless, NEVER auto. Companion to /reconcile (store-CONTENT drift, append-safe, runs often) and the shared detect-drift.ps1 engine."
user-invocable: true
disable-model-invocation: false
argument-hint: "[light | deep]"
---

# Deepclean Skill (filesystem janitor)

The file-lifecycle counterpart to `/reconcile`. `/reconcile` repairs store *content*
(INDEX rows, links, stale snapshots) by delegating to `/log` and `/goals`; it never
deletes a file. `/deepclean` owns the *filesystem*: it finds cruft that has outlived its
purpose and, only after you approve each tier, deletes / moves / archives it.

Because it does destructive filesystem ops, it is **manual, on-demand, and
propose-then-confirm** — the opposite of `/reconcile`'s headless cadence. It never runs on
a timer.

## The central test
Every finder operationalizes one question: **"Is this superseded by something that
SHIPPED?"** A plan whose skill now exists; a `drafts/` scaffold whose real dir exists; a
reminder dated before today; a MEMORY.md pointer whose file is gone; a fixture from
finished dev. If yes, it is a cleanup candidate. If unsure, it stays and gets surfaced, not
removed.

## DO-NOT-TOUCH denylist (non-negotiable)
Never propose deleting or moving harness-managed state. Treat these as read-only always:
`projects/`, `file-history/`, `plugins/`, `sessions/`, `shell-snapshots/`, `paste-cache/`,
`history.jsonl`, `.credentials.json`, `daemon/` keys + `daemon.*`, `.rate-limit-state.json`,
`policy-limits.json`, `statusline.ps1`, `settings.json`, `settings.local.json`, `themes/`,
`.inbox/` (PROPAGATE-lane message transport: self-sweeping on a 4h TTL and deleted on delivery, so
there is nothing to curate and a manual sweep would silently destroy an undelivered message),
`cache/`, `backups/`, `downloads/`, `session-env/`, `.run-from/` (kit-hook state,
self-pruning by design), `.kit-install-receipt.json` (LOAD-BEARING — the session-start
FRESH_USER/tutorial gate reads it; deleting it breaks onboarding), `remote-settings.json`,
`.last-update-result.json`, `.last-*` markers generally, and anything under a `.git/`. If a
candidate falls in here, drop it silently — do not even surface it.

## When to invoke
- `/deepclean` or `/deepclean light` (default) — structural + drift-engine + deterministic
  checks; no subagent fan-out. Cheap, good for a routine tidy.
- `/deepclean deep` — adds the parallel reader fan-out (one agent per store-family) for the
  superseded-by-shipped judgment that needs reading plans against built skills, drafts
  against real dirs, etc. Token-heavy; opt-in for a thorough periodic sweep.
- "deep clean the setup" / "sweep the stale files" / "what can we delete".

Do **not** trigger for: store-content drift (`/reconcile`), read-only status (the `/goals` board),
planning (`/goals`), single-thread capture (`/log`).

## Process

### Step 1 — Structural sweep + load the denylist
Map `~/.claude`: top-level inventory, per-dir file counts, sizes. Load the DO-NOT-TOUCH set
above. This frames scope and guarantees no harness state is ever a candidate.

### Step 2 — Run the shared drift engine first (reuse, don't reinvent)
Run the detector via PowerShell with an explicit root (a relative bash path leaves
`$PSScriptRoot` empty and it fails):
```
powershell -NoProfile -File "%USERPROFILE%\.claude\janitor\detect-drift.ps1" -ClaudeDir "%USERPROFILE%\.claude" -Quiet
```
(Plugin install: if the `janitor\` copy is absent, run
`${CLAUDE_PLUGIN_ROOT}/scripts/detect-drift.ps1` with the same `-ClaudeDir` argument; neither
present → note the engine is unavailable and continue with the structural finders only.)
Read `janitor/drift-latest.json`. Any store-content findings there are `/reconcile`'s job —
hand them off, do not act on them here.

### Step 3 — Run the finders
Each finder answers the central test for one store. In **light** mode do the deterministic
ones directly; in **deep** mode spawn one OBSERVATION-ONLY reader agent per store-family and
have it return a scannable digest (see Step 3b).

Finders:
- **`orphaned_plan`** — a `plans/*.md` describing an effort whose skill/output now exists
  (map plan topics against `skills/`, shipped projects, CLAUDE.md sections). Auto-slug names
  (`atomic-plotting-squirrel.md`) that describe shipped work are the strongest candidates.
- **`promoted_scaffold`** — a `drafts/<X>` subtree whose real target dir exists and is
  equal-or-richer. Keep scaffolds still gated behind a real-repo PR.
- **`memory_index_drift`** — for each `projects/*/memory/` scope: MEMORY.md pointer with no
  file, and file with no pointer (both directions); dangling `[[wikilinks]]`; self-marked or
  past-due dated memories. (The drift engine does NOT cover memory — this is deepclean's.)
- **`past_due_dated_file`** — `reminders/<date>.md` + its `.fired-<date>.log`, dated
  session-notes, any file whose name encodes a date before today.
- **`dev_leftover`** — test fixtures, blocked/parked stale `jobs/`, `tmp/` trees, superseded
  caches.
- **`doc_code_drift`** — a README/doc that describes something as unbuilt ("scaffold", "not
  implemented") when the code beside it is built. Report, don't auto-edit prose.
- **`stale_permission`** — one-off crumbs in `settings.local.json` (session-UUID-specific
  greps, absolute-path line-counts, OS-inapplicable paths). Propose-only; the user reviews
  each — never bulk-delete permissions.

#### Step 3b — deep-mode fan-out (only for `/deepclean deep`)
Spawn readers in parallel, one per family (threads+goals / memory / plans+drafts /
config+infra). Pass each the actual directory listing, and instruct: "counts are
approximate, VERIFY; seed suspicions as things to check, never as facts." Each returns a
factual digest; you synthesize — do not act from a single agent's word on a delete.

### Step 4 — Present as tiers (never auto-delete)
Group by confidence × reversibility, most-actionable first:
- **Tier 1 — safe deletes:** superseded/executed/leftover, high confidence. Print the EXACT
  file list per group.
- **Tier 2 — metadata fixes:** deterministic, near-zero risk (MEMORY.md pointer add/remove,
  malformed line drops). Show before/after.
- **Tier 3 — judgment calls:** duplicates needing confirmation, "looks done" threads,
  unrelated side-project files. One question each.
- **Flag-only:** genuine pending work, permission crumbs, doc drift — surface, do not sweep.
Confirm per tier before acting. State any exceptions you are KEEPING and why (deliberate
named plans, load-bearing latest files, PR-gated scaffolds).

### Step 5 — Execute the approved tiers
- Deletes: prefer plain removal (recoverable via `file-history/`); for anything you are
  unsure about, MOVE to an `archive/` rather than delete.
- Tab-delimited files (`links.tsv`): rewrite via a filter, not line edits (tabs mangle).
- After a thread/goal file is deleted, hand any resulting dangling `links.tsv` /
  MEMORY.md rows to the appropriate fixer (`/reconcile` for store links, this skill for
  memory index).

### Step 6 — Record the run
Stamp `~/.claude/.last-cleanup` with the current timestamp and append a one-line record
(what was removed vs deferred) to a `deepclean-log.md`, mirroring `janitor/drift-log.md`.
Report applied vs deferred.

## Guardrails
- **Never headless, never scheduled.** File deletion under a timer is how you lose something.
- **Never touch the denylist.** Not even to surface it.
- **Never edit append-only thread/goal `## Log` / `## Decisions`.** That is `/reconcile`'s
  delegated job; deepclean acts on whole files, not their innards.
- **Propose-then-confirm per tier.** The user is info-overload-sensitive — keep proposals
  scannable, exact filenames, no pasted file bodies.
- **Verify before you assert or delete.** Before calling a file load-bearing OR orphaned, grep
  for who actually reads/writes it — don't trust a prior claim, a README, or a subagent digest.
  A file is only safe to delete once its producers AND consumers are confirmed gone (e.g.
  `morning-latest.md` was safe only after grep showed no hook/skill touched it; its producing
  `skills/morning/` was deleted).
- **Re-check "already done" claims against the live file.** Subagent digests and cached snapshots
  lag — an item reported stale/unconfirmed may already be resolved (two "auto-unconfirmed" threads
  were already `[x]`). Re-grep the actual file before acting.
- **"Applied elsewhere" needs the destination checked, not assumed.** A staging/buffer file is only
  redundant once its content is confirmed in the canonical store — and check EACH part (the
  test-audit verdicts had landed on the ledger, but several fix-list follow-ups had not). Retire the
  landed part, preserve the rest; never blanket-delete a buffer.

## Versioning
New cleanup categories arrive as new finders in Step 3 + a Tier mapping in Step 4. If a
category needs deterministic detection, add it as a finding `kind` in `detect-drift.ps1`
ONLY if it is store-content drift; filesystem cleanup stays model-driven here, by design.
