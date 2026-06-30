# Mode: new (create a goal — capped interview, ≤5 prompts)

Also read `reference.md` (file format, store layout, guardrails).

Ask, stopping after each, skipping anything already supplied in the invocation:
1. Title (required → derive `id` = kebab-title).
2. North star (1–2 lines; skippable).
3. Which horizons apply, and **≥1 actionable Daily item** (the one required output).
4. Priority (default `normal`) and optional `review_after` date.
5. Optional thread links + relevance.

If the goal is complex or long-horizon, offer to escalate to `/grill-me` instead of the capped
interview (this is a behavior of `new`, not a separate skill).

**Dedup/consolidate (before drafting the file):** once the title + north star are known, scan
existing `active/*.md` for overlap. If the new goal substantially overlaps an existing one, **do not
create a second file** — propose folding it in instead: add the new Daily/Weekly items to the
existing goal (a `manage`-style edit) and/or add a thread link, and say which existing goal you
matched and why. Only create a fresh `active/<id>.md` when no active goal covers the same ground.
Bias toward extending over creating; when the match is borderline, ask which goal it belongs under
rather than silently splitting. (Mirrors `dump`'s dedup step so both creation paths consolidate.)

**Review gate:** show the drafted goal file (or the proposed extension); write nothing until
approved. On approval write `active/<id>.md` with `created = last_touched = <DATE>`, and add any link
rows to `links.tsv`.
