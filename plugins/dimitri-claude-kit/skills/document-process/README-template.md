<!--
  Template for `document-process` skill output.
  Keep the section order fixed — a future master-doc skill harvests these sections by heading.
  Delete a section only if it is genuinely not applicable; prefer "N/A" with a one-line reason
  over silent removal. Keep prose tight (Pass 5).
-->

# <ProjectName>

## Purpose
<!-- 1–2 sentences: what this project does and why it exists. No filler. -->

## What the name means
<!-- Decode the project name: source system, cadence, entity/acronym, destination.
     Mark anything the code can't confirm as an open question rather than asserting it. -->

## How it fits in
- **Project type:** <library | service | CLI | function | script | other>
- **Language / runtime:** <e.g. C# / .NET 10, Python 3.12, Node 20>
- **Upstream (inputs from):** <where data/calls come from>
- **Downstream (consumers):** <who/what uses its output>
- **Talks to:** <databases | queues | external APIs | other services | …>

## Data flow
<!-- A short numbered walkthrough of the main path: input → transform → output. -->
1. <input>
2. <transformation>
3. <output>

## Configuration
- **Config values:** <what it reads and from where: env vars, config files, constants>
- **Secrets:** <secret values it pulls and from where: env vars, a secrets manager, etc.>
- **Hardcoded / environment-specific values:** <flag explicitly, with file:line; "none found" if so>

## Running / debugging locally
<!-- How to invoke it and what must be present (files, connections, leases). Keep practical. -->

## Key types
<!-- The handful of classes/methods worth knowing — one line each. Not an exhaustive API dump. -->
- `<Type or Member>` — <one-line role>

## Gotchas & assumptions
<!-- Operational behavior that bites you: edge cases, ordering/timing assumptions, dedup,
     retries, error/failure modes, threading/idempotency assumptions. -->

## Known gaps / future work
<!-- Resolved-but-incomplete items: documented limitations, untuned/placeholder params, deferred
     handling, and any maturation path. These are NOT questions — they have answers, the work just
     isn't done. Omit only if there are genuinely none. -->
- <gap or future-work item>

## Open questions / for domain owner
<!-- ONLY genuinely-unanswered items that need a human. Resolved items graduate into the sections
     above during Pass 7. An empty section here ("None outstanding") is a good outcome — do not pad
     it with future-work items; those belong in Known gaps / future work. -->
- [ ] <question>

## Related
<!-- Sibling/related projects, downstream consumers, relevant docs or skills. -->
