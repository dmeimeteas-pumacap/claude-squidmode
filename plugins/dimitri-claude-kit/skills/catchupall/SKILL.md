---
name: catchupall
description: "Brief the user on ALL active threads at once (Tier 0 per thread). Use when the user says '/catchupall', 'catch me up on everything', 'what am I working on', 'show all threads', 'what's active', or wants a panoramic view of open efforts rather than a deep dive on one. Accepts 'all' for the full board, plus row-number selection and paging: 'top <n>', a single '<n>', a range '<a>-<b>', 'from <n>', or a list '<a>,<b>,<c>'. Prefix with 'view' (e.g. '/catchupall view all') for a print-only dump that renders full detail verbatim without synthesizing or internalizing it."
user-invocable: true
argument-hint: "[view] [all | top <n> | <n> | <a>-<b> | from <n> | <a>,<b>,<c>]"
---

# Catchupall Skill

Multi-thread briefing. Companion to `/catchup` (single thread) and `/log` (write). Surfaces all
active efforts at Tier 0 so the user can decide where to focus, then offers to drill deeper on any
one via `/catchup <slug>`.

## When to invoke

- `/catchupall`
- "catch me up on everything" / "what am I working on" / "show all threads" / "what's active" /
  "give me a panorama" / "all open efforts"

Do **not** trigger for resuming a single specific thread (use `/catchup`), capturing new state
(use `/log`), or general questions unrelated to thread state.

## Procedure

1. Read `~/.claude/threads/INDEX.md`. Find all rows under `## Active`. Number them `1..N` in INDEX
   order (priority + recency) — this is the cheap source of truth, one line per thread.

2. **Resolve the selection against those numbered rows *before reading any thread file*.** The
   argument decides which rows are *in scope*:
   - **none** → default. In scope = the first 5 rows (the auto-brief cap). If `N > 5`, you will note
     the rest in step 5.
   - `all` → rows `1..N` (the full board). Overrides the 5-row cap, same as any explicit selection.
     Use this for a cleanup/panorama pass over every active thread.
   - `top <n>` (e.g. `top 3`) → rows `1..n`.
   - a single `<n>` (e.g. `4`) → just row n.
   - `<a>-<b>` (e.g. `4-6`) → rows a through b inclusive.
   - `from <n>` or `<n>+` (e.g. `from 7`) → rows n through N (paging past the cap).
   - `<a>,<b>,<c>` (e.g. `1,3,5`) → exactly those rows.
   Clamp out-of-range numbers to the valid `1..N` set and say what you clamped. An explicit
   selection **overrides** the 5-row cap (the cap only governs the no-argument default).

   A leading **`view`** token (e.g. `view`, `view all`, `view 2-4`) is a *render mode*, not a
   selection — strip it, resolve the rest of the argument by the rules above, then follow step 7
   instead of steps 3-5. Bare `view` resolves like the no-argument default (first 5, paging noted).

3. **Read only the in-scope threads** — reads must equal what you display. For each selected row, do
   a **Tier 0 read** of its thread file (`~/.claude/threads/active/<slug>.md`):
   - frontmatter (`title`, `project`, `priority`, `last_touched`)
   - `## Where I left off`
   - `## Next`

   Do not open thread files outside the selection; INDEX (step 1) already carried everything needed
   to resolve it.

4. Present as a compact multi-thread briefing (not a file dump). Prefix each block with its INDEX row
   number so the user can page or pick by number. One block per thread:

   ```
   ### N. <title> [<project>] — last touched <date>
   **Where:** <one-sentence where-left-off>
   **Next:** <top 2-3 unchecked next items>
   ```

5. After all threads, offer (these lines, surfaced as a footer):
   - "Say `/catchupall view` for a verbatim full-detail dump of all of these, or `/catchupall view <n>` for one thread."
   - "Say `/catchup <slug>` (or `/catchup <n>`) to go deeper on any of these."
   - If the no-argument cap hid rows, show the count and how to page, e.g. "Showing 1-5 of 9 — say
     `/catchupall from 6` or `/catchupall 6-9` for the rest."
   - If any threads have `related:` links pointing at each other, note the connection briefly.

6. **`view [<n>]` (print-only full-detail dump, no internalizing).** Reached when the argument leads
   with `view` (step 2), invoked directly with **no preceding brief**. Render the in-scope threads at
   the **complete** content instead of the compact brief — the deliberate "everything the md holds" view.
   - Read each in-scope thread and print, **verbatim and untruncated**: the full `## Where I left off`
     paragraph, **every** `## Next` item (not the top 2-3), the **most-recent `## Decisions` entry**,
     and the **most-recent `## Log` entry**.
   - **Do not synthesize, summarize, paraphrase, comment, rank, or draw connections.** No "where to
     focus" framing, no recommendations, no footer offers. Print the content and stop — the point is
     a clean dump the user reads themselves, not a briefing you have internalized.
   - Bound it: never dump the entire `## Log` history (it grows without limit) — print only the most
     recent entry. For the full Log of one thread, point them at `/catchup <n>` (Tier 2). A `view` over
     many threads can be long — that is the user's explicit choice, so do not silently truncate, but if
     >8 threads are in scope, note the size and suggest narrowing (`view <n>`).

   ```
   ### N. <title> [<project>] — last touched <date> · <priority>
   **Where I left off:** <full paragraph, verbatim>
   **Next (all):**
   - [ ] <every open item>
   **Latest decision:** <most-recent ## Decisions entry>
   **Last log:** <most-recent ## Log entry>
   ```

## Guardrails

- **Read-only.** Does not write threads, INDEX, or memory.
- Tier 0 only unless the user asks to go deeper — that's `/catchup`'s job.
- In the **default brief**, if `## Where I left off` is longer than 2-3 sentences, summarize; don't
  paste the whole section. This cap applies to the brief ONLY — `view` (step 6) deliberately
  overrides it and prints the section verbatim.
- If there are no active threads, say so and offer `/catchup <topic|date>` for historical lookup.
- Cap **automatic** (no-argument) briefing at 5 threads; if more exist, brief the top 5 by index
  order (priority + recency) and tell the user the total plus how to page (`from <n>`, `<a>-<b>`,
  `top <n>`). An explicit numeric selection is never silently truncated — honor it, though you may
  note when it is large.
- **Read only what you display.** Resolve the selection against the INDEX rows first (step 2), then
  Tier-0-read only the in-scope threads. Never read all N files and trim afterward.

## Versioning

- If briefs are too dense → trim to one line per thread with a "say /catchup for more" offer.
- If trigger collides with `/catchup` → tighten `description` here; `/catchupall` is always
  multi-thread, `/catchup` is always single-thread.
- If selection grammar grows (tags, project filters) → extend step 2 and the `argument-hint`
  together so they stay in sync.
