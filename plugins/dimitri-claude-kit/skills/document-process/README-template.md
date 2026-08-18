<!--
  Template for `document-process` skill output.
  Lean "what / how / use" shape — straightforward and to the point (the reader wants functionality,
  not a line-by-line trace). Section order is fixed so a future master-doc skill can harvest by
  heading. Omit a section only if genuinely N/A (say so in one line). Systemic / cross-cutting
  findings belong in the section overview (document-section's `## Concerns Raised`), NOT repeated
  here — link back instead. Keep prose tight (Pass 5).
-->

# <ProjectName>

## What it is
<!-- 1–3 sentences: what this does and where the real logic lives (e.g. "thin host over <core library>").
     Fold any name-decoding (source system / cadence / acronym) in as a clause, not its own section. -->

## How it works
<!-- Quick-orient bullets, then the essential path — only the non-obvious, not a full trace. -->
- **Type / runtime:** <library | service | CLI | function> · <e.g. C# / .NET 10>
- **Inputs ← / Outputs → / Talks to:** <upstream> / <downstream> / <dbs, queues, APIs, services>
- **Flow:** <input → processing → output; a few numbered steps only if the path is non-obvious>

## How to run / use it
<!-- The usage section — WEIGHT IT BY WHAT THIS IS:
     • Service / CLI / function: how it's invoked or deployed, the config that actually matters,
       and how to run it locally (what must be present — files, connections, leases).
     • Library: how callers use it — the key entry points / types, one line each (not an API dump).
     Include Secrets by name + location (NEVER the literal value) and any hardcoded / env-specific
     value with file:line. -->

## Gotchas & assumptions
<!-- Behavior that bites: edge cases, ordering/timing, dedup, retries, failure modes, threading.
     Service-SPECIFIC only — systemic findings go up to the section overview. -->

## Known gaps / future work
<!-- Resolved-but-incomplete items: documented limits, untuned/placeholder params, dead code, a
     maturation path. NOT questions — they have answers, the work just isn't done. Omit if none. -->
- <gap or future-work item>

## Open questions / for domain owner
<!-- ONLY genuinely-unanswered items that need a human. Resolved items graduate into the sections
     above during Pass 7. An empty section ("None outstanding") is a good outcome — do not pad it. -->
- [ ] <question>

## Related
<!-- One or two links, not a web. In a section run this is a single line back to the section overview
     (e.g. "See ../<Section>.md for the cluster map and shared concerns") plus the core library. -->
