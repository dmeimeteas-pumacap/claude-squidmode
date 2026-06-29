# Log Skill — Lifecycle & Checkoff Modes

Read this file when the resolved `/log` mode is one of **pause (3c)**, **close (3d)**,
**confirm (3f)**, **done (3g)**, **split (3h)**, or **fullclose (3j)**. These fire rarely, so their full procedures live
here instead of in the always-loaded `SKILL.md` hot path. The step numbers below (step 4 = INDEX
regen, step 5 = correlation, step 6 = memory promotion) refer to the `## Process` section of
`SKILL.md`, which is already loaded.

## 3c — pause

Set `status: paused`, bump `last_touched`, write a one-line pickup hint into `## Where I left off`.
File stays in `active/` (paused work is still in-flight). Move its INDEX row to the **Paused**
table with the hint.

## 3d — close

Run **memory promotion** (step 6 in `SKILL.md`). Set `status: done`, bump `last_touched`,
**move** the file to `done/<slug>.md`. Move its INDEX row to **Recently done** with a one-line
outcome.

## 3f — confirm

Clear the unconfirmed marker left by a prior `auto` capture. This is a lightweight verification,
**not** a capture: do **not** append a `## Log` or `## Decisions` entry. Resolve the target: an
explicit `<slug>` wins; otherwise find the active thread whose `## Where I left off` carries the
`⚠ AUTO …` prefix (if more than one, list them and ask which). On the target: strip the
`⚠ AUTO (AI-selected thread, unconfirmed) — ` prefix from `## Where I left off`, and remove the
`[ ] Confirm this auto-capture landed on the right thread` item from `## Next`. Bump
`last_touched`. Then step 4 (INDEX row, now without the marker). Skip step 5 (correlation) and
step 6 (promotion). If the target has no `⚠ AUTO` marker, change nothing and say there is nothing
to confirm. If the user says the auto-pick went to the **wrong** thread, do **not** confirm — tell
them it needs a manual move (the entry can't be relocated by this mode) and stop.

## 3g — done (check off Next items)

The **canonical checkoff procedure** (`/catchup`'s checkoff step delegates here). A lightweight,
non-capture mode: tick off completed `## Next` items via a checkbox prompt. Do **not** append a
new state capture and do **not** add a `## Decisions` entry; this only records the completions.
Resolve the target as in 3b (explicit `<slug>`, or a clearly-named active thread; if nothing
named, read `INDEX.md`, show the **Active** table, and ask). Then:

- **Exclude** the auto-capture confirm item (`[ ] Confirm this auto-capture landed on the right
  thread`) from the list — clearing the `⚠ AUTO …` marker is `confirm` (3f)'s deliberate job. If
  that is the *only* open item, skip and point the user at `/log confirm`.
- Present the remaining open `- [ ]` items through the `AskUserQuestion` multiSelect checkbox
  prompt (one option per item, the item text as the label). If the user ticks nothing or
  dismisses, **change nothing**.
- For each ticked item: **remove** it from `## Next`; **append** one dated `## Log` entry for the
  whole batch in the standard shape — a `Did: checked off — <item text>` line per ticked item,
  then `Thinking: routine checkoff.` and `Next: <first remaining ## Next item, or "see ## Next">`.
  Bump `last_touched`.

Then step 4 (regenerate the INDEX row — `Last` = today; `## Where I left off` is unchanged so the
one-line cell and priority do not move). **Skip** step 5 (correlation) and step 6 (promotion).
Confirm: which items were checked off, that the Log entry was appended, and what remains in
`## Next`.

## 3h — split (carve a new thread out of an existing one)

Create a new thread by **relocating** a subset of an existing parent thread's notes into it. The
**one sanctioned exception** to the append-only rule: `## Log` / `## Decisions` entries are *moved*
(copied verbatim into the new thread, then removed from the parent), so the historical record is
preserved intact in its new home, not destroyed. Use this when an effort has outgrown a broader
thread and deserves its own. Do **not** use sub-threads — the system is intentionally flat; a split
produces a sibling thread linked via `related:`.

Trigger: "new thread X, move the Y work out of Z", "split the Y stuff into its own thread", or an
explicit `split "<title>" from <parent-slug>`.

Procedure:

1. **Resolve the parent** thread (explicit slug, or the clearly-named active thread the notes
   currently live in). **Propose** the new thread's `slug`/`title`/`project`/`topic`/`tags` exactly
   as in 3a and **WAIT for confirmation** before writing anything.
2. **Identify the entries to relocate.** Read the parent's `## Decisions` and `## Log` and list,
   for the user, which entries you read as belonging to the new thread. Confirm the set — a wrong
   move is costlier here than elsewhere because it edits append-only history.
3. **Create the new thread** (`active/<slug>.md`) per the 3a format. Seed its `## Decisions` and
   `## Log` by **copying the confirmed entries verbatim** (Log newest-first). Then add a fresh
   `## Log` entry capturing the current session's work, and seed `## Where I left off` + `## Next`
   from the conversation.
4. **Edit the parent (the destructive half):** **remove** the relocated `## Decisions` / `## Log`
   entries; **overwrite** `## Where I left off` and `## Next` to drop the migrated items; **append**
   one dated `## Log` marker entry — `Did: split <topic> work out into [[new-slug]]` /
   `Thinking: <why it earned its own thread>` / `Next: <parent's remaining focus>`. Bump
   `last_touched` on both files.
5. **Cross-link:** add `related: [[other-slug]]` to **both** frontmatters (this is step 5
   correlation, performed unconditionally for a split).
6. Step 4 (INDEX): **add** the new thread's row and **regenerate** the parent's row. Skip step 6
   (promotion) unless the parent is being closed in the same breath.

Confirm: the new slug, which entries were relocated (and that they were removed from the parent),
the parent's marker entry, and the `related:` link added to both.

## 3j — fullclose (close + sweep all open Next items)

A **close that ticks every remaining `## Next` item unconditionally**, then archives the thread.
Non-interactive — no checkbox prompt. Contrast `done` (3g), which is interactive, *excludes* the
auto-confirm item, and does **not** close: `fullclose` includes everything and closes. Use when an
effort is finished and any still-open Next items are either done or moot, and you want a clean
archive in one step.

Resolve the target as in close/done (explicit `<slug>`, or a clearly-named active thread; if nothing
named, read `INDEX.md`, show the **Active** table, and ask). Read only the **head** (Grep `^## Log`,
Read to that line + ~5 margin), same as 3b. Then:

1. **Sweep every open `## Next` item, unconditionally.** For **each** remaining `- [ ]` item —
   **including** the auto-capture confirm item `[ ] Confirm this auto-capture landed on the right
   thread` (do **not** exclude it, unlike 3g): **remove** it from `## Next` and record it in one
   batched dated `## Log` entry (newest-first under `## Log`) as a `Did:` line using the **distinct
   fullclose marker**:
   - `Did: ⚑ swept (fullclose) — <item text>` (one per swept item). The `⚑` flag distinguishes a
     fullclose sweep from `done`'s plain `Did: checked off — <item>`, so the archive shows which
     completions were bulk sweeps versus individually-verified checkoffs.
   - Then `Thinking: bulk-closed via fullclose; items not individually verified.`
   - Then `Next: —`.
   After the sweep, `## Next` should hold no open `- [ ]` items.
2. **Preserve the auto context.** Do **not** strip the `⚠ AUTO (AI-selected thread, unconfirmed) — `
   prefix from `## Where I left off` — clearing that marker stays `confirm` (3f)'s job. Sweeping the
   auto-confirm Next item does not mean the thread was genuinely confirmed; the `⚠ AUTO` prefix must
   survive into the archive so the auto-selection can still be reviewed later.
3. **Then run the close path (3d):** memory promotion (step 6 in `SKILL.md`), set `status: done`,
   bump `last_touched`, **move** the file to `done/<slug>.md`, and move its INDEX row (step 4) to
   **Recently done** with a one-line outcome.

Confirm: which items were swept (note the `⚑` marker), that the auto-prefix was preserved if present,
that promotion ran (or was skipped for a `general` thread), and that the thread was closed and moved
to `done/`.
