# Mode: manage (set | link | done)

Also read `reference.md` (file format, store layout, guardrails). Three small store edits:

## set `<id>` — direct edit, no interview
Resolve the goal by `id` (fuzzy-match the title if needed). Apply the change via a targeted edit or a
single clarifying prompt. Bump `last_touched`. **Lifecycle:** if the change sets `status` to `done`
or `abandoned`, move `active/<id>.md` → `done/<id>.md`; if back to `active`/`paused`, keep/return it
to `active/`.

## link `<goal-id> <thread-slug> [relevance]` — junction edge management
Add or edit a row in `links.tsv`: `goal-id <TAB> thread-slug <TAB> relevance` (TAB-separated; default
relevance `supporting`). Validate the goal exists (`active/` or `done/`) and the thread exists
(`~/.claude/threads/active/` or `/done/`). One edge per goal-thread pair — if the pair already
exists, update its relevance in place rather than appending a duplicate row. Query either direction by
reading the file (goal→threads or thread→goals).

## done `[<id>]` — check off horizon items
**With `<id>`:** resolve that goal, show its unchecked `### Daily`/`### Weekly` items; the user picks
which are complete.

**Without an id (bare `/goals done`):** run an interactive sweep across ALL active goals (do NOT
error or ask for an id). Read every active goal's unchecked `### Daily`/`### Weekly` items, then
present them through the `AskUserQuestion` multiSelect checkbox prompt — one option per item, labeled
`[goal-id] <item>` — exactly like `/log done`'s tick flow. Batch across calls when the item count
exceeds the ≤4-options / ≤4-questions caps; never silently truncate. If the user ticks nothing, change
nothing.

For each ticked item: flip `- [ ]` → `- [x]` in its goal file and bump that goal's `last_touched`.
(Mirrors `/log done`'s tick mechanic but operates on goal horizon checklists — no coupling to `/log`.)
Completing the *whole goal* is a `set` status change, not this.
