# Submode: plan dump (rambling prose → proposed areas/tasks)

Reached via `/goals plan dump` (or a stray top-level `/goals dump`). Contextless-first: draft
candidates from the prose on their own terms, then dedup/merge against existing areas (step 4).

Also read `reference.md` (store layout, area format, guardrails).

Pipeline:
1. Ingest the prose (from the argument, or ask the user to paste it).
2. Segment into candidate areas and/or loose tasks.
3. Per candidate area: draft title + north-star and **≥1 actionable task** (each with a timeliness
   tag) — if a candidate is pure musing, keep it as north-star prose rather than faking a task.
4. **Dedup against the existing `goals.md` areas**: a loose task usually belongs under an existing
   area — propose adding it there, not a new section. Only propose a new area when nothing covers
   the ground.
5. Suggest thread links + relevance.
6. **Mandatory review gate** — present the full proposed set; write nothing until approved.

Guardrail: **bias toward fewer/broader areas.** Merge aggressively, cap new areas at ~3 per dump,
and flag any over-broad candidate to split rather than silently creating many.

On approval, edit `goals.md` (insert sections / append tasks) and add `links.tsv` rows.
