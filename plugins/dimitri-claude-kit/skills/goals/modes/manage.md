# Mode: manage (set | link | done)

Also read `reference.md` (store layout, area format, guardrails). Three small store edits, all
against the single file `~/.claude/goals/goals.md`:

## set `<id>` — direct edit, no interview
Resolve the area by its `id:` metadata line (fuzzy-match the heading if needed). Apply the change
via a targeted edit or a single clarifying prompt (prio, review_after, north-star, task add/reword,
live_progress/thread lines). **Lifecycle:** retiring an area (done/abandoned) = CUT its whole `## `
section out of `goals.md` and write it to `done/<id>.md` (add a one-line header noting the retire
date + reason); reviving one = paste the section back. Clean the area's `links.tsv` rows only on
abandon (a done area's edges stay meaningful history).

## link `<area-id> <thread-slug> [relevance]` — junction edge management
Add or edit a row in `links.tsv`: `area-id <TAB> thread-slug <TAB> relevance` (TAB-separated;
default relevance `supporting`). Validate the area exists (a `goals.md` `id:` line, or `done/`) and
the thread exists (`~/.claude/threads/active/` or `/done/`). One edge per pair — if it already
exists, update its relevance in place rather than appending a duplicate. Query either direction by
reading the file. Also mirror the edge onto the area's `thread:` line in `goals.md` (display
convenience; `links.tsv` stays the store of record).

## done `[<id>]` — check off tasks
**With `<id>`:** resolve that area, show its unchecked tasks; the user picks which are complete.

**Without an id (bare `/goals done`):** run an interactive sweep across ALL areas (do NOT error or
ask for an id). Collect every area's unchecked tasks, then present them through the
`AskUserQuestion` multiSelect checkbox prompt — one option per task, labeled `[area-id] <task>` —
exactly like `/log done`'s tick flow. Batch across calls when the count exceeds the ≤4-options /
≤4-questions caps; never silently truncate. If the user ticks nothing, change nothing.

For each ticked task: flip `- [ ]` → `- [x]` in `goals.md`. If the task appears in today's tracker
plan (check `~/.claude/accountability/today-goalmap.tsv`), also tick the tracker item and refresh
the OneNote mirror (`modes/today.md` steps 4–5) so the three surfaces stay in step. Retiring a
*whole area* is a `set` lifecycle change, not this.
