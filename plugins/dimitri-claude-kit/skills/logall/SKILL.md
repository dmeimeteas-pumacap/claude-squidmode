---
name: logall
description: "Find all sessions where /log was never called and walk through them interactively one at a time, synthesizing each into a thread log entry. Use when the user says '/logall', 'log all sessions', 'catch up on unlogged sessions', or 'log everything I missed'. '/logall eod' runs the end-of-day wrap: sweep TODAY's unlogged sessions interactively, then chain into /eod for a copy-friendly daily summary."
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

## Discovery phase

Run the following shell commands via bash (Git Bash at
`C:\Program Files\Git\usr\bin\bash.exe`) to collect candidates. Use the same SCRIPT_DIR trick
as the hooks to derive `CLAUDE_DIR` if `$HOME` resolves incorrectly.

### Step 1 — collect JSONL sessions

```bash
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(cd "$HOOK_DIR/../.." && pwd)"   # ~/.claude
PROJECTS_DIR="$CLAUDE_DIR/projects"

# List all jsonl files with their modification date (YYYY-MM-DD) and parent folder name
find "$PROJECTS_DIR" -name "*.jsonl" -printf "%TY-%Tm-%Td\t%h\t%f\n" 2>/dev/null | sort
```

Each row: `date TAB folder_path TAB filename`

The folder name under `projects/` encodes the project path: each `-` in the encoded name is a
path separator or colon. Decode to get the project basename:
- Strip the `PROJECTS_DIR` prefix to get the hash folder name.
- The project name is the last segment of the decoded path (split on `-`, take the last meaningful
  part). For `C--Users-foo-source-repos-TheSquid` the project name is `TheSquid`; for
  `C--Users-foo-source-repos` (no trailing segment) the project name is `source-repos` or `repos`.
- If the folder name ends with only system dirs (`source-repos`, `repos`, or similar non-project
  names), treat the project as `general`.

Group JSONL files by `(project_name, date)`. Each unique pair is a candidate session.

### Step 2 — collect logged (project, date) pairs

Read every `.md` file under `~/.claude/threads/active/` and `~/.claude/threads/done/`. For each
file, extract:
- `project:` from the frontmatter
- Every `### YYYY-MM-DD` heading under `## Log`

Build a set of `(project, date)` pairs that are already logged. A session is **logged** if its
`(project_name, date)` matches any pair in this set.

### Step 2b — collect already-reviewed (skipped) pairs

Read the **reviewed ledger** at `~/.claude/threads/.logall-reviewed.tsv` (tab-separated, one row
per pair: `project⇥date⇥reviewed_on⇥reason⇥disposition`; the 5th field is optional and defaults to
`review`; may not exist yet — treat absence as empty). Rows are `(project, date)` pairs a prior
`/logall` run already inspected and the user judged not worth logging. Build two sets:
- **`reviewed`** — rows with `disposition` = `review` (or absent). Suppressed normally; `--recheck`
  brings them back (a previously-skipped chat may now fit a thread that did not exist before).
- **`permanent`** — rows with `disposition` = `permanent`. **Never** re-surfaced, even under
  `--recheck`. Use this for chats that will never belong anywhere but that you don't want to delete.

Physically **deleted** sessions need no ledger row — a removed JSONL is no longer a candidate.

### Step 3 — compute unlogged sessions

`unlogged = candidates − logged − reviewed − permanent`

**`--recheck`:** when this flag is passed, do **not** subtract `reviewed` (`unlogged = candidates −
logged − permanent`). `permanent` rows stay excluded regardless. Use this when threads have changed
since the last sweep — a previously-skipped chat may now belong to a thread that did not exist at
review time. Re-surfaced pairs go through the normal interactive flow; if skipped again, their
ledger `reviewed_on` is refreshed (see the Skip option).

Apply `--since` filter if provided (exclude sessions older than that date). Default: look back 30
days from today.

Sort unlogged sessions oldest-first. Report the total count before starting.

If zero unlogged sessions are found, say so and stop.

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

Produce a draft log entry in the `/log` format:

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
3. **Skip** — mark as reviewed-and-not-log-worthy and move on. **Record it in the ledger** so it
   is not re-checked next run: append (or, if a row for this `(project, date)` already exists,
   replace) a line `project⇥date⇥<today>⇥<one-line reason>⇥review` in
   `~/.claude/threads/.logall-reviewed.tsv` (create the file if missing). Use `Add-Content` to
   append; use today's date as `reviewed_on`. Skips done under `--recheck` refresh the existing
   row's `reviewed_on` rather than adding a duplicate.
4. **Delete (garbage)** — for sessions with no durable value at all (greeting-only, immediately
   interrupted, throwaway scratch). **Delete the underlying session JSONL file(s)** for the chat.
   Because the file is then gone, it can never be re-examined by any flag, and no ledger row is
   needed. **Hard requirement:** never delete without first listing the exact file path(s) and
   getting explicit confirmation; delete only files clearly identified as garbage (not a whole
   `(project, date)` group that also holds real work). Deletion is irreversible and also drops the
   chat from `claude --resume` history and `/eod` reconstruction — only use it when that loss is nil.
5. **Permanently ignore** — never log, but keep the file. Write the ledger row with `disposition`
   = `permanent` (5th field). These are excluded from every future run, including `--recheck`.

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

On accept or edit:

1. **Resolve the target thread** — infer from the project name which active thread this belongs
   to (check `project:` in thread frontmatter). If multiple threads match, ask. If none match,
   offer to create a new thread or add to an existing one by slug.

2. **Append the log entry** to that thread's `## Log` section under a `### YYYY-MM-DD` heading.
   If a heading for that date already exists (e.g. from a partial earlier capture), append below
   the existing entry under the same heading.

3. **Overwrite `## Where I left off` and `## Next`** only if this session is the most recent one
   being written (i.e. the last in the batch, or if the date is newer than `last_touched`).

4. **Bump `last_touched`** to the session date if it's newer than the current value.

5. **Regenerate the INDEX row** for the touched thread.

Then move to the next unlogged session.

### After all sessions

Report: how many sessions were processed, how many written, how many skipped, and which threads
were updated. Close with a one-line, non-blocking tip showing the other modes:
`tip: /logall eod chains into the daily wrap; --since YYYY-MM-DD scopes the lookback; --recheck re-surfaces skipped sessions.`

## Guardrails

- Write only under `~/.claude/threads/` — thread files (`## Log`, `## Where I left off`, `## Next`,
  `last_touched`) and the reviewed ledger `.logall-reviewed.tsv`. Never edit `## Decisions`
  retrospectively unless the synthesis explicitly identified a decision made in that session.
- The reviewed ledger only records the `(project, date)` key, a date, and a short reason — never
  session content, file contents, or secrets.
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
- The reviewed ledger (`.logall-reviewed.tsv`) suppresses re-checking of skipped pairs; `--recheck`
  bypasses it for `review` rows but not `permanent` rows. Garbage sessions are deleted outright (no
  ledger row). If the ledger schema or disposition values change, update Step 2b, Step 3, and the
  interactive options together.
