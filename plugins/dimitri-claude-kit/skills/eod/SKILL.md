---
name: eod
description: "Cross-project synthesis of a single day's sessions. Reads that day's thread Log entries, auto-wrap logs, and JSONL transcripts to produce a unified daily handoff. Explicit-only: runs when the user types '/eod', and is invoked by /catchup in date-reconstruction mode. Does NOT auto-trigger on ambient phrases — capturing is /log, resuming is /catchup."
user-invocable: true
disable-model-invocation: true
argument-hint: "[YYYY-MM-DD]  (target date; defaults to today)"
---

# EOD Skill

Produce a cross-project synthesis of a single day's sessions. Two modes:
- **Today (default, `/eod`)**: write `~/.claude/session-notes/eod-latest.md` (overwritten). The
  session-start hook loads this as a fallback when there are no active threads.
- **Reconstruction (a past date, usually invoked by `/catchup`)**: synthesize the given day and
  return the briefing to the caller; do **not** overwrite `eod-latest.md` with old data.

## Target date
Read an optional `YYYY-MM-DD` argument. If absent, use today (`currentDate` system-reminder if
present, else `date +%Y-%m-%d`). Everywhere below, `<DATE>` is this resolved target date.

## When to invoke
- `/eod` (today)
- Invoked by `/catchup <date>` for past-day reconstruction.

Explicit-only. Ambient capture is `/log`; ambient resume is `/catchup`.

## Output
- Today mode: `~/.claude/session-notes/eod-latest.md` — always overwritten.
- Reconstruction mode: return the synthesis to the caller; no file write.

---

## Process

### Step 1 — Auto-capture current session (today mode only)
If `<DATE>` is today and the current session's work hasn't been captured to a thread yet, run a
`/log` capture first so the live conversation (the only directly-accessible session) is recorded.
In reconstruction mode (past date), skip — there is no live session for that day.

### Step 2 — Discover all of `<DATE>`'s sources

Use `<DATE>` to find:

**A. Thread Log entries**
Scan `~/.claude/threads/active/*.md` and `~/.claude/threads/done/*.md` for `## Log` entries dated
`### <DATE>`. These are the richest source — already structured (Did/Thinking/Next) and carry the
rationale via each thread's `## Decisions`. (Days predating the thread system usually lack these, but check anyway — threads can carry back-dated entries — and fall back to B/C when absent.)

**B. Auto-wrap logs** (mechanical captures from Stop hook)
Glob: `~/.claude/session-notes/auto/YYYY-MM-DD-*-auto.log`
Each log has timestamped blocks of `git status --short` output showing what changed per turn.
For each log, derive the project name from the filename: `YYYY-MM-DD-<ProjectName>-auto.log`.

**C. JSONL transcripts** (sessions with no thread entry and no auto-log, or to enrich them — and
the primary source for days that predate the thread system)
Find JSONL files for `<DATE>` in `~/.claude/projects/`. On Windows, filter by mtime:
```powershell
Get-ChildItem -Path "$env:USERPROFILE\.claude\projects" -Recurse -Filter "*.jsonl" |
  Where-Object { $_.LastWriteTime.Date -eq ([datetime]'<DATE>').Date }
```
The folder containing each JSONL encodes the project path
(e.g., `C--Users-<you>-source-repos-MyApp` → project `MyApp`).
Cross-reference against thread entries and auto-logs to identify which JSOLs represent sessions not yet covered.

**Reading JSOLs**: Scan for:
- Edit/Write tool calls → what files were changed and what was written
- Assistant messages containing decisions, design choices, deferrals, or explicit "next steps"

JSONL files can be large. Read them and focus extraction on tool results and assistant turns. If a file is too large to read in full, read the last third (most recent context) and note the truncation.

### Step 3 — Synthesize

Produce a unified daily handoff. Work section by section:

**Projects touched today** — one line per project: what category of work happened (new feature, debugging, documentation, Q&A, etc.).

**Key decisions** — design choices made, approaches selected, things ruled out. Tag each with its project. A decision with a rationale is more valuable than one without.

**Work still in progress** — tasks started but not finished, blockers, and explicit deferrals. Be specific: not "working on X" but "X — Pass 1 done, Pass 2 pending."

**Files changed today** — union of all files changed across all sources. One entry per file with the project and a short reason. Derive from git status output (auto-logs), Edit/Write tool calls (JSOLs), and thread `## Log` "Did" lines.

**Tomorrow's priorities** — ordered, actionable items. Synthesize across all projects into a single prioritized list. Each item must be specific enough to act on cold. (In reconstruction mode this is "open items as of `<DATE>`" rather than literal tomorrow.)

**Sessions without recoverable context** — list any sessions where no thread entry, no auto-log, and no readable JSONL existed. These are permanent gaps.

### Step 3b — Follow-through (today mode only; gated)
Gate: run only if `~/.claude/session-notes/morning-latest.md` exists **and** is dated `<DATE>`. If
it is absent or stale, skip this step entirely — output is unchanged on days with no morning
intention.

Read the morning intention (the chosen primary move + intended items) from `morning-latest.md`.
For each intended item, use the day's already-discovered sources (Step 2A thread `## Log` entries
and the Work-still-in-progress findings) to narrate whether it moved. Add a `## Follow-through`
section, one line per item: `Committed: <X> — <what the day's sources show>.`

Narrative only — no score, no percentage, no streak, no cadence. Reuses Step 2's discovery; add no
new scanning. This is the morning↔EOD loop-close, deliberately minimal until the accountability
layer exists.

### Step 4 — Output

- **Today mode:** write `~/.claude/session-notes/eod-latest.md` using the structure below.
- **Reconstruction mode (past `<DATE>`):** return the same synthesis to the caller (`/catchup`).
  Do **not** overwrite `eod-latest.md` — that file represents the most recent day, not a past one.

Structure:

```markdown
# EOD — YYYY-MM-DD

> Sources: N thread entries, N auto-logs, N JSOLs synthesized.
> Sessions with no recoverable context: [none | list]

## Projects touched today
- <ProjectName> — <one-line summary>

## Key decisions
- <decision> [<ProjectName>]

## Work still in progress
- <item> [<ProjectName>]

## Follow-through   (today mode only; omit entirely if no morning intention for <DATE>)
- Committed: <intended item> — <what the day's sources show>

## Files changed today
- `path/to/file` — <ProjectName> — what changed

## Tomorrow's priorities
1. <most important — specific, not vague>
2. ...
```

### Step 4b — Echo to console (copy-friendly, OneNote-safe)
After writing (today mode) or synthesizing (reconstruction), print the full report to the console
inside a single fenced code block so it renders as one selectable, copy-paste-ready box.

Do **NOT** echo the raw markdown. Dimitri pastes this into OneNote, which renders no markdown and
drops/mangles non-ASCII glyphs. Instead emit an **ASCII-only, indented-outline** rendering of the
same content:
- **ASCII only** — replace `—`->`-`, `→`->`->`, `©`->`(c)`, `×`->`x`, smart quotes->straight quotes,
  and any other non-ASCII glyph with a plain equivalent.
- **No markdown markup** — no `#`, `**`, backticks, or `>`. Section titles are plain lines at the
  left margin; items indented 4 spaces; sub-detail indented 8. No `-`/`*` bullets (leading
  whitespace lets OneNote apply its own outline levels on paste). The one exception is the numbered
  Tomorrow's-priorities list, where a plain `1.` `2.` is fine.
- **Every entry is a node, not a paragraph** — each list item (Key decisions and
  Work-still-in-progress included, not just Projects) is a short topic line at the 4-space indent
  with its explanation nested as sub-detail at 8. Never emit a multi-line entry flat at a single
  indent — adjacent entries then merge into one unreadable block.
- **Keep the fence** — it is the terminal-selection mechanism; only the content inside changes.

This is a console echo, not a file write — it does not violate the single-write guardrail. Note the
`eod-latest.md` file written in Step 4 **stays markdown** (the session-start hook consumes it); only
this console echo is ASCII/outline.

### Step 5 — Confirm
Tell the user:
- Path written
- How many sources were synthesized (N wraps + N auto-logs + N JSOLs)
- Which projects were covered
- Any sessions with no recoverable context
- **(today mode only)** a one-line, non-blocking tip showing the other mode:
  `tip: /eod YYYY-MM-DD synthesizes a past day.`

---

## Guardrails
- Today mode writes **only** `~/.claude/session-notes/eod-latest.md`. Reconstruction mode writes
  nothing — it returns the synthesis to the caller. No other writes in either mode.
- Do not modify thread files, auto-logs, source code, or config files.
- Do not include credentials, secrets, or connection strings.
- JSONL reading is best-effort — never fail hard on parse errors; log the failure and skip.
- If no sources exist at all for `<DATE>` (no thread entries, no auto-logs, no JSOLs), say so and
  skip writing rather than producing an empty file.

---

## Gotchas
- Only the **current session's live conversation** is directly accessible. Other sessions are accessible only via their written artifacts (thread entries, auto-logs, JSOLs).
- JSONL files can be very large (10MB+). Read them but focus on tool calls and assistant turns; skip raw user messages unless they contain explicit decisions or deferrals.
- `eod-latest.md` is loaded by the session-start hook **only as a fallback when there are no active threads**. Once a thread is active, the hook surfaces the active-thread dashboard instead.
- Running `/eod` multiple times in a day is safe — each today-mode run overwrites with a fresh synthesis.
- The `auto/` subdirectory is created by `auto-wrap.sh` on first use. It may not exist on first run.
- On Windows, JSONL files are at `%USERPROFILE%\.claude\projects\<hash>\<session-id>.jsonl`. The hash encodes the project path with `\` and `:` replaced by `-`.
- **Windows JSONL parsing: use PowerShell, not a scripting CLI.** `jq` and `node` are not installed, and `python`/`python3`/`py` all resolve to broken Windows Store stubs. The durable, dependency-free path is PowerShell `Get-Content file | ForEach-Object { $_ | ConvertFrom-Json }` (5.1 is always present, no version to go stale). Only if you genuinely need Python, discover the real interpreter by glob rather than hardcoding a version — `Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python*\python.exe"` — because bare `python` is the stub. If you do write a Python helper, put it in a temp `.py` file with raw strings and run that; do not embed Windows paths in a bash heredoc, where backslashes mangle into bad escape sequences.
- Subagent transcripts live under `<session-id>/subagents/agent-*.jsonl`. They are spawned by a parent session, not independent sessions — count the parent `<session-id>.jsonl` files for the real session tally, not the subagent files.

---

## Versioning
- If trigger misfires → tighten the `description` frontmatter first.
- If JSONL synthesis quality is poor → add a gotcha describing the specific failure and refine the extraction instructions.
- When the session-start hook format changes → update the output structure to match.
