---
name: log
description: "Capture working state to a continuity THREAD — an effort tracked across days (code or thought). Appends a dated Log entry (Did/Thinking/Next), optional Decision with rationale, and refreshes the thread's Where-I-left-off + Next + INDEX row. Use when the user says '/log', 'log this', 'wrap-up', 'wrap up the session', 'save my place', 'note where I am', 'capture this', or describes finishing/parking work. Lifecycle: 'new thread', 'pause this', 'close this thread'. '/log auto' auto-selects the best-fit thread (no prompt, marked unconfirmed for later review). '/log confirm' (or 'mark the X thread correct', 'confirm the auto-capture', 'that auto-log went to the right thread', 'yes that was the right thread') clears that marker. '/log done [<slug>]' (or 'check off the completed next steps', 'mark these next items done') ticks off finished '## Next' items. '/log micro' (or 'quick log', 'tiny log', 'log this quickly') does a lightweight capture for a trivial change — a one-line Log entry, no Decision, no correlation scan, Where-I-left-off untouched. '/log fullclose [<slug>]' (or 'full close', 'close and check everything off', 'close and tick all the boxes') closes a thread AND sweeps every remaining '## Next' item into the Log as done (non-interactive, unconditional — distinct from the interactive 'done'). Replaces the old wrap skill. NOT for a single project's mechanical file-change snapshot — threads track the why, not just the what."
user-invocable: true
argument-hint: "[new \"title\" | <slug> | micro [<slug>] | auto | confirm [<slug>] | done [<slug>] | pause <slug> [\"reason\"] | close <slug> | fullclose <slug> | split \"title\" from <parent-slug>]"
---

# Log Skill

Capture state to a **thread**: one append-only file per effort that survives across days and
projects, holding the current state, the next actions, and — most importantly — the decisions and
the reasoning behind them. This is the canonical durable record. It replaces `wrap`.

## When to invoke

- `/log`
- "log this" / "wrap-up" / "wrap up the session" / "save my place" / "note where I am" /
  "capture this" / "park this"
- Lifecycle phrasing: "start a new thread on X", "pause this thread", "close this thread"
- Split phrasing: "new thread X, move the Y work out of Z", "split the Y stuff into its own thread"
- Confirm phrasing: "/log confirm", "mark the X thread correct", "confirm the auto-capture",
  "that auto-log went to the right thread", "yes that was the right thread"
- Checkoff phrasing: "/log done", "check off the completed next steps", "mark these next items done"
- Micro phrasing: "/log micro", "quick log", "tiny log", "log this quickly" (trivial change, cheap capture)
- Fullclose phrasing: "/log fullclose", "full close", "close and check everything off", "close and tick all the boxes" (close + sweep all open Next items)

Do **not** trigger for: general code explanations, conversational recap, or a request to
synthesize a whole day across projects (that is `/eod`, invoked via `/catchup`).

## Store layout

```
~/.claude/threads/
  INDEX.md            # derived dashboard — one row per thread
  active/<slug>.md    # active + paused threads
  done/<slug>.md      # closed threads (kept readable for /catchup recall)
```

`slug` = `YYYY-MM-<kebab-title>` (creation month + kebab title), e.g.
`2026-06-symbol-converter-cache`. The date prefix gives natural sort and disambiguates reused
titles.

## Thread file format (load-bearing — section names are read by `/catchup`)

```markdown
---
title: <human title>
slug: <YYYY-MM-kebab-title>
status: active            # active | paused | done
created: YYYY-MM-DD
last_touched: YYYY-MM-DD
project: <repo name | general>     # the realm
topic: <sub-specification>         # the effort's subject within the realm
tags: [<tag>, ...]
priority: normal          # high | normal | low   (reserved for future layer)
related: []               # ["[[other-slug]]", ...] cross-references
goal: null                # reserved seam — future goal layer
review_after: null        # reserved seam — future orientation/resurfacing layer
---

# <title>

## Where I left off
<one paragraph, present tense, written for cold-you. OVERWRITTEN every capture.>

## Next
- [ ] <ordered open items. OVERWRITTEN every capture.>

## Conventions
- <OPTIONAL — standing rules the effort applies repeatedly (NOT completable tasks). Omit the section entirely if the thread has none. Overwritten like `## Next`; holds rules, never checkboxes to complete; NOT parsed as open work by `/catchup` or the session-start banner.>

## Decisions
- **YYYY-MM-DD — <one-line claim>.**
  Why: <forcing reason>.
  Considered: <alternatives and why they lost>.
  Reversible? <cost to undo + the trigger that should make you revisit>.

## Log
### YYYY-MM-DD
- Did: <observable change>
- Thinking: <live mental state — what was uncertain / the hypothesis. Never skip this.>
- Next: <intended next action at that moment>
```

**Append-only sections** (`## Decisions`, `## Log`) are never edited. A superseded decision gets a
new dated entry, not an edit — the reasoning chain must stay intact. New `## Log` entries are added
**newest-first**, directly under the `## Log` heading (most recent on top). **Overwritten sections**
(`## Where I left off`, `## Next`, `## Conventions`) are cheap rolling pointers; the Log + Decisions retain history. `## Conventions` is optional (see the format above) — a thread carries one only when it has standing rules that would otherwise clutter `## Next`.

## Process

1. **Determine date.** Use the `currentDate` system-reminder if present; else `date +%Y-%m-%d`.

2. **Resolve the target thread** from the argument / conversation:
   - `new "title"` → go to step 3a.
   - `micro [<slug>]`, or natural micro phrasing ("quick log", "tiny log", "log this quickly") → step 3i (lightweight capture).
   - a slug, or a clearly-named active thread → that thread.
   - `auto` → go to step 3e (auto-select, no prompt).
   - `confirm [<slug>]`, or natural confirm phrasing → go to step 3f (clear the unconfirmed marker).
   - `done [<slug>]`, or natural checkoff phrasing → go to step 3g (check off completed `## Next` items).
   - `pause <slug> ["reason"]` → step 3c. `close <slug>` → step 3d.
   - `fullclose <slug>`, or natural full-close phrasing ("full close", "close and check everything
     off", "close and tick all the boxes") → step 3j (close + sweep all open `## Next` items).
   - `split "<title>" from <parent-slug>`, or natural split phrasing (new thread that reassigns
     notes out of an existing one) → step 3h.
   - nothing named → read `INDEX.md`, show the **Active** table, and ask which thread to capture
     to. With that prompt, list the available modes so the options are visible (non-blocking — the
     user can answer with a slug or any mode): `new "title"`, `<slug>`, `micro [<slug>]`, `auto`,
     `confirm [<slug>]`, `done [<slug>]`, `pause <slug>`, `close <slug>`, `fullclose <slug>`,
     `split "title" from <parent-slug>`. Do not guess silently.

3. **Act by mode:**

   **3a — new:** **Propose the name and WAIT for confirmation before writing anything.** Derive a
   `title` from the conversation, the `slug` as `YYYY-MM-<kebab-title>`, and inferred
   `project`/`topic`/`tags`, then show all of them to the user and ask them to confirm or amend.
   **Do not create the file until the user has accepted or edited the proposed name** — this is a
   required checkpoint, not optional. Once confirmed, build `active/<slug>.md` from the format
   above (`status: active`, `created`/`last_touched` = today), seed `## Where I left off` and
   `## Next` from the conversation, add the first `## Log` entry. Then step 4 (INDEX) and step 5
   (correlation).

   **3b — capture (default):** Read only the **head** of the thread file, not the whole thing —
   the append-only `## Log` grows without bound and is never needed to capture. Procedure:
   - `Grep` the thread file for `^## Log` to get its line number.
   - `Read` the file with `limit` = the `## Log` line number **plus a small margin** (~5 lines), so
     the head includes everything above `## Log`, the `## Log` heading itself, and the most-recent
     existing `### <date>` entry heading (your insertion anchor) — while still excluding the bulk of
     the Log history below.
   - **Overwrite** `## Where I left off` and `## Next` with `Edit` (both are in the head you read).
   - If a real decision was made, **append** a `## Decisions` entry in the fixed 4-line shape with
     `Edit` (the `## Decisions` block is in the head).
   - **Insert** the new `### <date>` `## Log` entry (Did/Thinking/Next) **newest-first — immediately
     after the `## Log` heading, above the most-recent existing entry** — with `Edit`, anchored on
     `## Log` + the first existing `### ` heading you read. Newest-first keeps the freshest entry on
     top, where `/catchup`'s tiered read looks first.
   - Bump `last_touched` (in the head you read) — **only if it differs from today**; if it already
     equals today's date, skip the edit entirely (no add-then-revert). Then step 4 + 5.

   **3i — micro (lightweight capture):** For a **trivial** change — nothing decided, nothing a
   future session must reason about (e.g. a one-line config tweak, a typo fix, a constant changed).
   The cheapest path; deliberately skips the expensive steps:
   - Resolve the target thread exactly as the default capture does: an explicit slug or a clearly-
     named active thread is used directly; if nothing is named and no thread is a clear match, fall
     back to normal `/log` resolution — read `INDEX.md`, show the **Active** table, and prompt the
     user to pick (or offer `new`). Never auto-guess in micro mode.
   - Read only the **head** (Grep `^## Log`, Read to that line + ~5 margin), same as 3b.
   - **Insert** a one-line `### <date>` Log entry newest-first under `## Log` — a single
     `- <terse what-changed>` line. No Did/Thinking/Next sub-structure.
   - Bump `last_touched` — **only if it differs from today**; if it already equals today's date,
     skip the edit entirely (no add-then-revert).
   - **Skip** the `## Where I left off` and `## Next` overwrites, the `## Decisions` append, the
     correlation scan (step 5), and memory promotion. Touch none of them.
   - **INDEX (step 4), reduced:** update only the touched row's `Last` date and its one-line cell
     (a short summary of this micro change). Leave priority and ordering alone. This intentionally
     lets the INDEX cell diverge from the thread's `## Where I left off` first sentence — see Gotchas.
   - **Bail-out:** if, while writing, the change turns out to involve a real decision or to advance
     the thread's state, stop and tell the user this warrants a normal `/log`, not `micro`.

   **3e — auto:** Same as 3b (capture), but **do not prompt** for the target. Infer the best-fit
   active thread from the conversation's topic/files/project and proceed. The capture is marked
   AI-selected and unconfirmed so the choice gets a human check later, using only sections
   `/catchup` and the session-start hook already read — no edits to those tools required:
   - Title the Log entry `### YYYY-MM-DD (auto — AI-selected, unconfirmed)` instead of the plain
     date heading.
   - Prefix the overwritten `## Where I left off` with `⚠ AUTO (AI-selected thread, unconfirmed) — `
     so the marker rides into the INDEX one-line cell and the catchup Tier-0 view.
   - Make the first `## Next` item `[ ] Confirm this auto-capture landed on the right thread`.
   If no active thread is a clear fit (low confidence), **do not invent one and do not silently
   create a thread** — stop and tell the user it needs `/log new` or an explicit slug. Then step 4 + 5.

   **3c — pause / 3d — close / 3f — confirm / 3g — done / 3h — split / 3j — fullclose (lifecycle & checkoff modes):**
   these fire rarely and their full procedures live in the bundled file `modes-lifecycle.md` (in this
   skill directory). When the resolved mode is one of these, **read `modes-lifecycle.md` and follow
   the matching section** (3c pause, 3d close, 3f confirm, 3g done, 3h split, 3j fullclose). 3g (`done`)
   remains the canonical checkoff writer that `/catchup` delegates to. 3h (`split`) is the **only** mode
   allowed to relocate append-only entries (see Guardrails). 3j (`fullclose`) is a close (3d) that first
   sweeps every open `## Next` item into the Log unconditionally — non-interactive, includes the
   auto-confirm item, and preserves the `⚠ AUTO` prefix (contrast 3g `done`, which is interactive,
   excludes the auto-confirm item, and does not close). Each runs step 4 (INDEX) as directed there;
   3d and 3j also run step 6 (memory promotion, below). The newest-first Log-insert rule (see Gotchas)
   applies to the `## Log` entry that 3g, 3h, and 3j write.

4. **Regenerate the INDEX row** for the touched thread only. Active/Paused row columns: Thread
   (`[[slug]]`), Project, Prio, Last (`MM-DD`), and the one-line cell (first sentence of
   `## Where I left off`, or the pause hint). Update the `_Updated …_` date line. Do not rewrite
   rows for threads you did not touch.

   **Priority order:** The Active table must stay sorted High → normal → low. When placing the
   updated row, remove its old position and re-insert it into the correct priority group. If its
   priority changed, it moves groups; otherwise it goes to the end of its existing group. Never
   reorder rows you did not touch within their group.

5. **Correlation scan.** Compare the touched thread's `topic`/`tags`/title against other threads
   (active + done). If one looks like the same or a strongly related effort — especially a
   `general` thread vs a `project` thread — tell the user and **offer** to add a `related:
   [[other-slug]]` link to both. Never merge files; separate-but-linked by design.

6. **Memory promotion (close only).** For each `## Decisions` entry, ask: "durable fact future
   sessions should always know?" If yes and the thread's `project` is a real repo, write the
   **distilled conclusion** (not the deliberation) to that project's `memory/` and add a
   `source: threads/done/<slug>.md` pointer; update that project's `MEMORY.md` index. The full
   rationale stays only in the closed thread. For `general` threads there is no project memory
   home — the archived `done/<slug>.md` is the durable record; say so and skip promotion.

7. **Confirm.** Report: thread slug, what was appended/overwritten, whether a decision was
   recorded, any correlation link offered, and (on close) what was promoted to memory.

## Guardrails

- Write **only** under `~/.claude/threads/` and (on close, for promotion) the relevant
  `memory/` files. No source code, no config, no other writes.
- Never edit or delete past `## Decisions` or `## Log` entries. Append only. **One exception:**
  `split` mode (3h) *relocates* entries into a newly-created thread — copied verbatim into the new
  file, then removed from the parent — so the record is preserved in its new home, never destroyed.
  This is the only sanctioned removal, and only when carving out a new thread.
- Do not include credentials, secrets, connection strings, or API keys.
- Create `~/.claude/threads/active/` or `done/` if missing before writing.
- If the work was trivial (pure Q&A, nothing decided or advanced), say so and skip rather than
  writing an empty Log entry.

## Gotchas

- `currentDate` may be in a system-reminder; prefer it over a shell `date` call for consistency.
- **`last_touched` bump is conditional.** In every mode that bumps `last_touched` (capture 3b,
  micro 3i, and the lifecycle modes in `modes-lifecycle.md`), only edit the field if its current
  value differs from today. If it already equals today's date, skip the edit — do not add and then
  revert a line.
- **Never read a whole thread file to capture.** The append-only `## Log` grows without bound and
  is never needed. Read only the head (frontmatter → the `## Log` heading + the most-recent entry),
  and **insert new `## Log` entries newest-first, immediately under the `## Log` heading**, via
  `Edit` anchored on that heading — never a full-file Read + Write, and never an EOF append (the
  newest entry goes on top, not the bottom). This caps the per-capture read regardless of thread age.
- The `## Where I left off` overwrite is intentional and lossless — the prior state is preserved
  in the append-only `## Log`. Do not "protect" it by appending.
- INDEX is derived. If it drifts from a thread file, the thread file wins; regenerate the row.
- **`micro` (3i) intentionally diverges INDEX from the thread.** It updates the INDEX one-liner but
  not `## Where I left off`, so the cell no longer equals the section's first sentence. This is
  expected and transient — the next normal capture (3b) regenerates the row from `## Where I left
  off` and the micro summary rolls off. Do not "fix" this divergence by rewriting Where-I-left-off
  during a micro capture; that would defeat the mode.
- A thread spanning multiple repos uses the realm where it primarily lives in `project`, captures
  the rest in `tags`, and links siblings via `related`.
- `auto` mode trades a confirmation prompt for the unconfirmed marker. The canonical way to clear
  it is `confirm` mode (3f) — a deliberate user act. Do not strip the `⚠ AUTO …` prefix or the
  confirm checkbox as a side effect of an unrelated normal capture unless the user has actually
  confirmed the thread choice; the explicit confirm is what closes the loop.

## Versioning

- If triggers misfire (e.g. catching plain "wrap" meant for something else) → tighten the
  `description` frontmatter first.
- The section names are read by `/catchup` and by the session-start hook's INDEX parse — if you
  rename them here, update `catchup/SKILL.md` and `session-start-global.sh` too. The `done` mode
  (3g) is the canonical checkoff writer of `## Next`/`## Log`; `/catchup`'s checkoff delegates to
  it, so the format lives here — now in the bundled `modes-lifecycle.md`. `/catchup` references the
  `done` mode **by label (3g)**, not by location, so relocating it there needs no `catchup` edit.
- Lifecycle/checkoff modes (3c/3d/3f/3g/3h/3j) live in `modes-lifecycle.md` for token economy (loaded
  only when one of those modes fires). **`micro` (3i) deliberately stays inline in this file** — it
  is the cheapest path, so routing it through the bundled file would force a `micro` call to load
  `modes-lifecycle.md` on top of `SKILL.md`, costing more, not less. Do not move it. If you rename a mode or change which step it delegates to,
  update both `SKILL.md`'s stub and `modes-lifecycle.md`.
