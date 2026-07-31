# Mode: new (create an area — capped interview, ≤5 prompts)

Also read `reference.md` (store layout, area format, guardrails).

Ask, stopping after each, skipping anything already supplied in the invocation:
1. Title (required → derive `id` = kebab-title).
2. North star (1–2 lines; skippable, but push once — it is the anchor that keeps the area from
   degrading into a flat to-do tag).
3. **≥1 actionable task** (the one required output), each with a timeliness tag
   (`{deadline:… | this-week | evergreen}`; default `evergreen`).
4. Priority (numeric, lower = higher; default 3) and optional `review_after` date.
5. Optional thread links + relevance.

If the area is complex or long-horizon, offer to escalate to `/grill-me` instead of the capped
interview (a behavior of `new`, not a separate skill).

**Dedup/consolidate (before drafting):** once title + north star are known, scan the existing
`goals.md` areas for overlap. If the new area substantially overlaps an existing one, **do not
create a second section** — propose folding in: add the new tasks to the existing area (a
`manage`-style edit) and/or add a thread link, and say which area you matched and why. Only add a
fresh `## ` section when no area covers the same ground. Bias toward extending over creating; when
borderline, ask which area it belongs under. (Mirrors `dump`'s dedup step.)

**Review gate:** show the drafted area section (or the proposed extension); write nothing until
approved. On approval, insert the section into `goals.md` in prio order, and add any link rows to
`links.tsv`.
