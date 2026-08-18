# Documentation Coverage Ledger

Tracks documentation status across the codebase. Updated by `document-section` on each run.
Do not edit the table manually — `document-section` owns it. Notes and comments below the table are fine.

## Coverage Table

| Project | Category | Tier | Mode | Status | Doc path | Source path | Open Qs (H/L/R) | Last run |
|---|---|---|---|---|---|---|---|---|
| _example: ExampleProject_ | Function | Brief | create | done | `Documentation/sections/Functions/ExampleProject.md` | `src/ExampleProject` | 0/1/2 | 2025-01-15 |

### Category values
Abstract buckets. Label each row with the repo's own family name where it has one (discovered in
Phase A), and map it to the bucket it belongs to.
- `Service` — long-running services: daemons, hosted workers, containers
- `Function` — serverless or trigger-driven function projects
- `Library` — shared first-party libraries
- `Tests` — test projects
- `Other` — legacy, uncategorized, or special-case projects

### Mode values
- `create` — no README existed at run start; full Create mode run
- `update` — README already existed; Update mode patch

### Status values
- `pending` — not yet started this run
- `in-progress` — subagent dispatched, not yet returned
- `done` — README written and checkpoint complete; open-question counts recorded
- `failed` — subagent errored or returned unexpected output; see Notes below
- `skipped` — explicitly excluded by user request, or already fresh on a re-run

### Open Qs column (H/L/R)
- `H` — human-high: high-relevance questions requiring user/domain input
- `L` — human-low: low-relevance questions requiring user/domain input
- `R` — ref-blocked: questions pending automatic resolution once the referenced project is documented (Phase F backfill)

## Notes

<!-- Add any manual notes about specific projects or runs here. -->
