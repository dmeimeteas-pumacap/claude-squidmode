---
name: catchup
description: "Resume a continuity THREAD and brief the user on where they left off and why past decisions were made. Use when the user says '/catchup', 'catch me up', 'refresh me', 'where was I', 'what was I working on', 'remind me about X', or asks to pick up a past effort or recall a specific day. Resolves three retrieval modes: exact thread slug, fuzzy topic recall (searches active AND closed threads), or a date (reconstructs that day via the eod tool). Reads in tiers so a months-long thread never floods context. After briefing a single thread, offers a checkbox prompt to check off completed Next items."
user-invocable: true
argument-hint: "[<slug> | <topic query> | <date>]"
---

# Catchup Skill

Re-orient the user on an effort. The companion to `/log`: `/log` writes threads, `/catchup` reads
them and briefs. Optimized so day-to-day pickup is cheap and month-later recovery is possible
without dumping an entire thread history into context.

## When to invoke

- `/catchup`
- "catch me up" / "refresh me" / "where was I" / "what was I working on" / "remind me about X" /
  "pick up where I left off" / "what was important on <date>"

Do **not** trigger for: capturing new state (that is `/log`), or general questions unrelated to
resuming prior work.

## Retrieval modes — resolve the argument to ONE before reading

1. **Exact slug** (e.g. `2026-06-symbol-converter-cache`) → load that thread directly. Go to
   **Tiered read**.

2. **Fuzzy topic** (e.g. "the symbol-cache thing from a few weeks back", "the Bloomberg
   onboarding") → search `title` / `topic` / `tags` / `## Decisions` / `## Log` across **both**
   `~/.claude/threads/active/` and `~/.claude/threads/done/`. Present the ranked matches (slug +
   one-line where-left-off + last_touched), let the user pick, then **Tiered read**. Closed
   threads are searched precisely so "a while back" work is recoverable.

3. **Date** (e.g. "2026-05-12", "what was important last Tuesday") → resolve to `YYYY-MM-DD` and
   invoke **`eod` in reconstruction mode for that date** (`eod` accepts a target-date argument).
   It synthesizes that day from: thread `## Log` entries dated that day, auto-logs
   (`~/.claude/session-notes/auto/YYYY-MM-DD-*-auto.log`), and JSONL transcripts under
   `~/.claude/projects/<hash>/` whose mtime falls on that date. This works even for days **before**
   the thread system existed, because JSONLs persist per session. Brief the user on what that day
   contained and why it mattered.

4. **No argument** → read `INDEX.md`, show the **Active** table with a leading `#` column numbering
   rows `1..N` in index order, and ask which thread to resume. With that prompt, list the available
   forms so the options are visible (non-blocking — the user can answer with any of them): a **row
   number**, a `<slug>` (resume by name), a `<topic query>` (fuzzy search of active + closed
   threads), or a `<date>` (reconstruct that day).

5. **Bare row number** (e.g. `/catchup 3`) → the thread at that position in `INDEX.md`'s **Active**
   table (index order = priority + recency). Resolve it to that one thread, then **Tiered read**.
   The numbering matches `/catchupall`'s blocks, so a number seen there pulls up the same thread here.

## Tiered read (single-thread modes)

Never blindly `cat` a whole thread. Read in tiers, stop as soon as you have enough:

- **Tier 0 (always):** frontmatter + `## Where I left off` + `## Next` (~15 lines). Day-to-day
  pickup usually stops here.
- **Tier 1 (default for a week+ gap, or any fuzzy/date resolve):** Tier 0 + the **entire
  `## Decisions`** section + the **last 3 `## Log`** entries. The standard month-later load;
  bounded because Decisions grows slowly. This is where the *why* lives.
- **Tier 2 (only on explicit "show everything" / reconstructing a specific moment):** full
  `## Log`.

Pick the tier from how stale `last_touched` is and what the user asked. When unsure between 0 and
1, choose 1 — the rationale is the point of coming back.

### Co-evolving siblings (lazy sibling load)
If the resolved thread's frontmatter has a **`coevolves_with`** list, its sibling(s) are declared
co-evolving — always contextually relevant, not merely "related." **Lazily** load them:
1. Read the main thread at the tier you picked above.
2. Then read each sibling's **Tier 0 only** (frontmatter + `## Where I left off` + `## Next`) and
   fold it into your understanding — the sibling is assumed relevant unless clearly not.
3. Escalate a sibling to Tier 1 **only as the task needs it** (e.g. the user's question turns on the
   sibling's decisions, or the main thread's Next points into it). Don't Tier-1 every sibling by default.
This is the standing "always aware of the other" behavior — no "want me to pull up X?" prompt for
co-evolving siblings (that prompt is for plain `related:` links); state briefly that you're carrying
the sibling's context. `coevolves_with` is symmetric — reading either sibling loads the other.

## State questions sweep live sessions, not just the thread

A thread file records what was WRITTEN. A concurrent conversation that has not logged yet is invisible
in it, so briefing straight off `## Where I left off` can hand back a confidently stale answer. Before
briefing, run a cheap freshness sweep on the resolved thread:

1. List `~/.claude/projects/*/` session `*.jsonl` files with an mtime **after** the thread's
   `last_touched` (subagent files under `*/subagents/` belong to their parent session).
2. Keyword-grep them for the thread's `topic`/`tags`/title terms and rank — **on the USER's turns
   only** (`grep -oE '"role":"user","content":"[^"]{0,600}'` into a scratch file, then grep that).
   Whole-transcript ranking is useless here: the session-start hook injects the EOD recap into every
   session, so recap topics score high in sessions that never touched them.
3. Read the top candidates, or name them as **unswept** in the briefing. An unread candidate is never
   reported as covered.
4. Skip any session already listed in `threads/.logall-processed.tsv`.

Scale it to the ask. A day-to-day "where was I" on a thread touched today needs no sweep. Escalate it
whenever the question is about **state** rather than rationale ("what is left", "where are we", "did we
ever resolve X", "is that done"), and whenever `last_touched` is older than the newest session file.

If the sweep finds real unlogged work, **hand it to `/log`** rather than briefing around it: say what
was found, name the thread, and delegate. `/catchup` does not write the capture itself (see Guardrails);
leaving a found gap uncaptured is the failure mode to avoid, because the finding otherwise dies with
this conversation.

## Briefing

After reading, brief in a few sentences, not a file dump:
- Where they are now (`## Where I left off`).
- The most relevant past decision(s) and **why** (from `## Decisions`).
- The next physical action (`## Next`).
- Any **correlated** threads (from `related:`), offered as "want me to also pull up X?". (For
  `coevolves_with` siblings, don't offer — you've already lazily loaded their Tier 0; just note it.)
- Whether the freshness sweep ran, and any sessions left **unswept**. Say "swept, nothing newer" or
  name the UUIDs you did not read. Never let a brief imply completeness the sweep did not establish.

**Whenever the sweep ran, append ONE line to `~/.claude/janitor/sweep-log.md`** (create with an
`# Sweep log` header if absent) — same format `/reconcile` Step 5 writes, with `src=catchup`:
`- <ISO timestamp>  cand=<N> read=<N> found=<N> persisted=<N> deferred=<N>  threads=<slug>  src=catchup`
A sweep leaves no other artifact once the conversation ends, so without this line there is no way to
tell later whether the freshness layer is actually firing. Skip the line only when the sweep was
legitimately skipped (a same-day pickup that needed none) — do not write a fake zero row for it.

Then offer the verbose escape hatch: "Say `view` to see the complete detail." On `view`,
escalate the read one tier if needed (Tier 0 → Tier 1) and print, **verbatim and untruncated**: the
full `## Where I left off` paragraph, **every** `## Next` item, the **entire `## Decisions`**
section, and the **last 3 `## Log`** entries — the same raw context you read from the md, not a
summary. Only go to Tier 2 (full `## Log`) if the user asks for everything after that. This is the
default-brief's escape hatch; it stays read-only (no checkoff side effects).

## Checkoff (single-thread modes only)

After briefing, if the resolved thread has open `- [ ]` items in `## Next`, offer to check off the
ones the user has since completed. This is the **one** write `/catchup` is allowed to perform, and
it **delegates to `/log`'s `done` mode (3g)** — the canonical checkoff procedure lives there, so the
two stay in sync.

1. **Applies only** to single-thread modes (exact slug, fuzzy resolved to one thread, or the
   no-argument Active-table pick). **Skip entirely** in date/`eod` mode — there is no single target
   thread to write to.
2. Run the **`done` procedure from `/log` (3g)** against the resolved thread: it excludes the
   auto-capture confirm item, presents the open items via the `AskUserQuestion` multiSelect checkbox
   prompt, and on tick removes each item from `## Next`, appends the batched dated `Did:` `## Log`
   entry, bumps `last_touched`, and regenerates the INDEX row. If the user ticks nothing or
   dismisses, it changes nothing and `/catchup` stays read-only for that thread.

## Interaction footer

After the briefing (and after the Checkoff prompt, if any), print a compact, dimmed footer
reminding the user how to act on this thread via `/log` — so the available verbs are visible
without typing them out in full. Keep it to these lines, verbatim:

```
─ act on this thread ─
/log done — check off completed Next items   ·   /log — capture current state
/log micro — quick one-line capture          ·   /log pause <slug> · /log close <slug>
```

Print it once, at the very bottom. Skip it in date/`eod` mode (no single target thread).

## Guardrails

- **Near read-only — one exception.** The *only* write `/catchup` performs is the **Checkoff** step
  above, which delegates to `/log`'s `done` mode (3g): removing user-ticked items from a single
  thread's `## Next`, appending the matching `Did:` `## Log` entry, bumping `last_touched`, and
  regenerating that thread's INDEX row. It writes nothing else — no new state capture, no
  `## Decisions`, no memory. Capturing fresh state is still `/log`'s job. (It may also *invoke*
  `eod`, which writes only its own synthesis file.)
- **The freshness sweep is a READ, and its follow-up is a delegation.** Sweeping live sessions adds no
  write; if it finds unlogged work, `/catchup` hands off to `/log` rather than capturing it inline, so
  the one-write rule above still holds. Reporting the finding and stopping is not acceptable, but nor
  is writing the capture here.
- Respect the tier budget — do not load Tier 2 unless explicitly asked or genuinely needed.
- If no thread matches a fuzzy query, say so and offer the Active table or a date search rather
  than fabricating a match.

## Gotchas

- `eod` is explicit-only (`disable-model-invocation: true`); `/catchup` is the normal way it gets
  invoked for past-day reconstruction. Pass it the resolved target date.
- JSONL transcripts can be large — for date reconstruction, focus on tool calls and assistant
  turns; note any truncation. (eod already encodes this discipline.)
- Section names are produced by `/log`. If they change there, update the tier parser here.
- A date with no thread, no auto-log, and no readable JSONL is a permanent gap — report it
  honestly rather than guessing what happened.

## Versioning

- If fuzzy search quality is poor → refine the rank signals (weight `title`/`topic` over `## Log`
  body) and add a gotcha.
- If triggers collide with `/log` → tighten this `description` and `/log`'s; `/catchup` is read,
  `/log` is write.
