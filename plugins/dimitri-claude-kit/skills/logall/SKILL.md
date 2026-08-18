---
name: logall
description: "Find all sessions not yet individually logged and walk through them interactively one at a time, synthesizing each into thread log entries (a session may update MORE THAN ONE thread). Tracking is per session UUID, not per (project,date), so concurrent same-day threads can't mask each other. Use when the user says '/logall', 'log all sessions', 'catch up on unlogged sessions', or 'log everything I missed'. '/logall eod' runs the end-of-day wrap: sweep TODAY's unlogged sessions interactively, then chain into /eod for a copy-friendly daily summary."
user-invocable: true
argument-hint: "[eod] [--since YYYY-MM-DD] [--recheck]"
---

# Logall Skill

Find every Claude session that has no corresponding thread `## Log` entry and walk through them
interactively, synthesizing each into a proper log entry using the same format as `/log`.

## When to invoke

- `/logall`
- "log all sessions" / "catch up on unlogged sessions" / "log everything I missed"

Do **not** trigger for: logging a specific current session (that is `/log`), or reviewing a
specific thread (that is `/catchup`).

## EOD wrap mode (`/logall eod`)

A comprehensive end-of-day wrap: "make sure everything impactful I did today is logged, then give
me the EOD summary to paste into my notes." This is the manual counterpart to the scheduled `/eod`,
for when work continued after the timed run.

**As of the sweep-first change, `/eod` (today mode) runs this sweep itself** — its Step 1 performs
the today-scoped sweep (Discovery + Interactive, current session excluded) *before* synthesizing.
So `/logall eod` is now a thin convenience alias: **invoke `/eod` (today mode)** and let it own the
whole flow (sweep today's unlogged sessions → capture the current session → synthesize → echo the
copy-ready report). Forward `--recheck` / `--since` to that run if the user passed them.

Do **not** run the sweep here and *then* call `/eod` — that would sweep twice (the second pass
finds nothing, but it is wasted work and confusing). One sweep, owned by `/eod`.

Net result of `/logall eod` (unchanged for the user): every impactful session from today is durably
in its thread, and a fresh, copy-ready EOD summary is on screen.

## Granularity: track per SESSION, not per (project, date)

**This is the load-bearing design rule.** A candidate and its logged/reviewed state are keyed by
the **session UUID** (the JSONL filename without extension), never by `(project, date)`. The old
`(project, date)` key was the source of a silent data-loss bug: you run many concurrent threads per
project (a busy project routinely has 5-7 active threads), so a single logged entry in one thread marked
the whole `(project, date)` day as "logged" and every sibling thread's session that day was
subtracted as already-covered and never surfaced. Session-UUID keying makes sibling threads
impossible to mask — each session must be handled on its own before it drops off the list.

A single session can also touch **more than one thread** (e.g. a docs session that advances both the
knowledge-system and the visualization threads). The write step therefore fans out to **every**
thread the session touched, not one inferred thread. See *Write*.

## Discovery phase

Run the following shell commands via bash (Git Bash at
`C:\Program Files\Git\usr\bin\bash.exe`) to collect candidates. Use the same SCRIPT_DIR trick
as the hooks to derive `CLAUDE_DIR` if `$HOME` resolves incorrectly.

### Step 1 — collect JSONL sessions (one candidate per session UUID)

```bash
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(cd "$HOOK_DIR/../.." && pwd)"   # ~/.claude
PROJECTS_DIR="$CLAUDE_DIR/projects"

# session_id (filename stem) TAB date TAB folder_path
# -mindepth/-maxdepth 2: TRUE session files sit directly in a project hash folder.
# ! -name 'agent-*': exclude subagent transcripts, which live in <session>/subagents/
#   and are NOT user sessions (they would flood + mis-key discovery otherwise).
find "$PROJECTS_DIR" -mindepth 2 -maxdepth 2 -name "*.jsonl" ! -name "agent-*" \
  -printf "%f\t%TY-%Tm-%Td\t%h\n" 2>/dev/null | sort
```

Each JSONL file is ONE candidate session, identified by its filename stem (the session UUID).
Decode the parent folder name to a `project_name` exactly as before: strip the `PROJECTS_DIR`
prefix; the project is the last meaningful segment of the `-`-decoded path (`C--Users-foo-source-repos-MyProject`
→ `MyProject`); folders ending in only system dirs (`source-repos`, `repos`) → `general`. Carry
`(session_id, project_name, date, path)` for each candidate. Do **not** group by `(project, date)`.

### Step 0 (first run only) — migrate legacy coverage into the processed ledger

If `~/.claude/threads/.logall-processed.tsv` does **not** exist, seed it once so the switch to
session-level tracking does not re-surface months of already-captured history:

- Read every `.md` under `threads/active/` and `threads/done/`; collect the set of `(project, date)`
  pairs that have a `### YYYY-MM-DD` heading under `## Log` (the old "logged" signal).
- For every candidate session **strictly before today** whose `(project, date)` is in that set,
  write a processed-ledger row (disposition `logged-migrated`, see Step 2 format).
- Do NOT seed today's sessions — today is where precise per-session capture must start.

This migration deliberately inherits the old coarse `(project, date)` signal for **history only**
(we are not retro-splitting past multi-thread days); everything from today forward is session-precise.
Tell the user how many rows were seeded.

### Step 2 — subtract already-processed sessions (by UUID)

Read the **processed ledger** `~/.claude/threads/.logall-processed.tsv` (tab-separated; may be
absent → empty). One row per handled session:

```
session_id ⇥ project ⇥ session_date ⇥ processed_on ⇥ disposition ⇥ threads_written
```

`disposition` ∈ { `logged`, `logged-migrated`, `review` (skipped as not-worth-logging),
`permanent` (never re-surface) }. `threads_written` is a comma-separated slug list (may be empty).
Build:
- **`processed`** — rows with disposition `logged` / `logged-migrated` / `review`. Suppressed
  normally; `--recheck` brings the `review` ones back (not `logged*`).
- **`permanent`** — never re-surfaced, even under `--recheck`.

Physically **deleted** sessions need no row — a removed JSONL is no longer a candidate.

### Step 2b — honor the legacy (project, date) reviewed ledger

Also read the old `~/.claude/threads/.logall-reviewed.tsv` (`project⇥date⇥reviewed_on⇥reason⇥disposition`,
5th field defaults to `review`; may be absent). Its rows are legacy `(project, date)` review/permanent
decisions. Suppress any candidate whose `(project, date)` matches a `review` row (unless `--recheck`)
or a `permanent` row (always). This preserves prior manual skips without re-flooding; new skips are
written session-level to `.logall-processed.tsv`, not here.

### Step 3 — compute unlogged sessions

`unlogged = candidates − processed − permanent − legacy_reviewed`

**`--recheck`:** do not subtract the `review` rows (`.logall-processed.tsv` disposition `review`,
and legacy `.logall-reviewed.tsv` `review`). `logged*` and `permanent` stay excluded regardless.

Apply `--since` if provided (exclude sessions older than that date). Default: look back 30 days.

Sort unlogged sessions oldest-first. Report the total count before starting. If zero, say so and stop.

### The current (in-progress) session

**Plain `/logall` INCLUDES the running session.** Its JSONL already exists and is a normal candidate;
a common reason to run `/logall` is precisely to capture the session you are in, so do not exclude it.
It will be the newest, still-growing file — synthesize from what is there and note it may be
mid-flight. **Exception: `/logall eod` (and any `--unattended`/`/eod`-driven sweep) EXCLUDES the
current session**, because `/eod` captures the current session itself in a separate step; including
it here would double-write. So: exclude-current only on the eod path, include-current everywhere else.

## Interactive phase

For each unlogged session, in order:

### Read the JSONL

Read the JSONL file(s) for this `(project, date)` pair. Focus on:
- User messages (the questions/directives that drove the session)
- Assistant turns describing what was done or decided
- Tool calls that show concrete file edits, git operations, or shell commands run

Skip binary-looking content, large data blobs, and repeated boilerplate. If the file exceeds
~500 lines, read the first 100 and last 100 lines, noting the truncation.

### Synthesize

**First determine which thread(s) the session touched.** Match by `project:` to narrow the
candidate threads, then read each candidate's `## Where I left off` / `topic` / `tags` / slug and
compare against the session's actual work (files edited, subjects discussed, thread slugs mentioned).
A session may map to **one, several, or zero** existing threads:
- **One or several** → produce a **separate, thread-specific** draft entry per touched thread (each
  entry describes only that thread's slice of the session — do not paste the same generic entry into
  all of them).
- **Zero** → offer to create a new thread (never drop the session).

For each touched thread, produce a draft log entry in the `/log` format:

```
**Date:** YYYY-MM-DD  **Project:** <name>

**Did:** <one or two sentences — observable changes, the concrete thing that happened>
**Thinking:** <what was uncertain, the hypothesis, the mental state — never skip this>
**Next:** <the most likely intended next action based on how the session ended>

**Decisions (if any):**
- <one-line claim> — Why: <reason>. Considered: <alternatives>. Reversible? <cost to undo>
```

Keep it honest. If the session was pure Q&A with nothing advanced, say so — the user may choose
to skip it.

### Present and confirm

Show the synthesis to the user. Offer three options:

1. **Accept** — write it as-is
2. **Edit** — user provides corrections, then write
3. **Skip** — mark as reviewed-and-not-log-worthy and move on. **Record it in the processed ledger**
   (session-level) so it is not re-checked next run: append a line
   `session_id⇥project⇥session_date⇥<today>⇥review⇥` to `~/.claude/threads/.logall-processed.tsv`
   (create the file if missing; `Add-Content` to append). If a row for this `session_id` already
   exists, replace it. Skips done under `--recheck` refresh the existing row's `processed_on`.
4. **Delete (garbage)** — for sessions with no durable value at all (greeting-only, immediately
   interrupted, throwaway scratch). **Delete the underlying session JSONL file(s)** for the chat.
   Because the file is then gone, it can never be re-examined by any flag, and no ledger row is
   needed. **Hard requirement:** never delete without first listing the exact file path(s) and
   getting explicit confirmation; delete only files clearly identified as garbage (not a whole
   `(project, date)` group that also holds real work). Deletion is irreversible and also drops the
   chat from `claude --resume` history and `/eod` reconstruction — only use it when that loss is nil.
5. **Permanently ignore** — never log, but keep the file. Write a processed-ledger row
   `session_id⇥project⇥session_date⇥<today>⇥permanent⇥`. Excluded from every future run, including
   `--recheck`.

If the user edits, apply their corrections to the draft before writing.

**Non-interactive (auto-accept) sweep.** When the sweep is driven by an unattended caller —
specifically `/eod --unattended` from the scheduled launcher, where no human is present to answer —
skip "Present and confirm" entirely and **auto-accept every synthesis**, writing each as a log
entry. Do not offer skip/delete/permanent, and never delete a file. Mark each auto-written entry as
AI-synthesized and unconfirmed (the `/log auto` markers: a `### <DATE> (auto — AI-selected,
unconfirmed)` Log heading, the `⚠ AUTO (AI-selected thread, unconfirmed) — ` prefix on any
overwritten `## Where I left off`, and a leading `[ ] Confirm this auto-capture landed on the right
thread` Next item) so the entries are reviewable later via `/log confirm`. If a session maps to no
existing thread, create one rather than dropping it — the priority is never losing context.

### Write

On accept or edit, apply to **each** touched thread (the set resolved in Synthesize):

1. **For every touched thread** (not just one):
   a. **Insert the thread-specific log entry** newest-first, immediately under `## Log` (above the
      most-recent existing `### ` entry), per the `/log` newest-first rule. If a `### <date>` heading
      for this date already exists, append below it under the same heading.
   b. **Overwrite `## Where I left off` and `## Next`** only if this session is that thread's most
      recent activity (its date ≥ the thread's `last_touched`). An older backfilled session must not
      clobber a newer thread's pointers — append its Log entry only.
   c. **Bump `last_touched`** to the session date if newer than the thread's current value.
   d. **Regenerate the INDEX row** for that thread.

2. **Record ONE processed-ledger row for the session** (not per thread): append
   `session_id⇥project⇥session_date⇥<today>⇥logged⇥<slug1,slug2,…>` to
   `~/.claude/threads/.logall-processed.tsv`, listing every thread written. This is what stops the
   session from re-surfacing next run.

Then move to the next unlogged session.

### After all sessions

Report: how many sessions were processed, how many written, how many skipped, and which threads
were updated. Close with a one-line, non-blocking tip showing the other modes:
`tip: /logall eod chains into the daily wrap; --since YYYY-MM-DD scopes the lookback; --recheck re-surfaces skipped sessions.`

## Guardrails

- Write only under `~/.claude/threads/` — thread files (`## Log`, `## Where I left off`, `## Next`,
  `last_touched`) and the two ledgers: `.logall-processed.tsv` (session-level, the primary) and the
  legacy `.logall-reviewed.tsv` (read-only for suppression; do not add new rows to it). Never edit
  `## Decisions` retrospectively unless the synthesis explicitly identified a decision made in that session.
- The ledgers record only keys (session UUID / project / date), a date, a disposition, and (for
  skips) a short reason and the written thread slugs — never session content, file contents, or secrets.
- Do not fabricate content. If the JSONL is unreadable or empty, say so and offer to skip.
- Never **edit** a session JSONL file. The only permitted destructive action is **deleting** a
  whole garbage session file under the Delete disposition, and only after the user confirms the
  explicit path(s). Never delete the currently-running session, and never delete a file that holds
  real work alongside the garbage.
- A session with only system messages or tool noise and no meaningful user/assistant exchange
  should be flagged as "trivial" — let the user decide to skip rather than auto-skipping.

## Versioning

- If the JSONL format changes → update the "Read the JSONL" section.
- If the project-path encoding scheme changes → update the decoding rule in Step 1.
- If `/log`'s thread format changes → update the synthesis template and write step to match.
- **Tracking is per session UUID** (`.logall-processed.tsv`), not per `(project, date)` — this is the
  fix for concurrent same-day threads masking each other. `/log` also stamps this ledger when it
  captures the current session (best-effort), so a manual `/log` does not make its session
  re-surface here. The legacy `.logall-reviewed.tsv` `(project, date)` file is honored read-only for
  old skips (Step 2b). `--recheck` bypasses `review` rows in both, never `logged*`/`permanent`.
  Garbage sessions are deleted outright (no row). If the ledger schema or dispositions change, update
  Step 0, Step 2, Step 2b, Step 3, the interactive options, and the Write step together.
- If `/log` cannot resolve its session UUID to stamp the processed ledger, that is non-fatal: the
  session simply surfaces once in the next `/logall`, where the user skips it (recorded) — self-healing.
