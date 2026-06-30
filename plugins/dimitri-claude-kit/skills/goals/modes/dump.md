# Mode: dump (rambling prose → proposed goals)

Also read `reference.md` (file format, store layout, guardrails).

Pipeline:
1. Ingest the prose (from the argument, or ask the user to paste it).
2. Segment into candidate goals.
3. Per candidate: draft title + north-star, classify items into `Daily`/`Weekly`/`Larger`, and
   **force ≥1 actionable Daily item** — if a candidate is pure musing, file it as `Larger` prose
   rather than faking a task.
4. **Dedup against existing `active/*.md`**: if a candidate overlaps an existing goal, propose
   extending/linking it, not a new file.
5. Suggest thread links + relevance.
6. **Mandatory review gate** — present the full proposed set; write nothing until approved.

Guardrail: **bias toward fewer/broader goals.** Merge aggressively, cap new goals at ~3 per dump, and
flag any over-broad candidate to split rather than silently creating many.

On approval, write/merge the `active/<id>.md` files, add `links.tsv` rows, bump `last_touched`.
