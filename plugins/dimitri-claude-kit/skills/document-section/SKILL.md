---
description: "Document a defined SECTION of the codebase — a set of projects, a category (e.g. all Squid.AzFn.* services), a directory, or the whole codebase — by orchestrating the document-process skill across each target. Use when the user asks to document multiple projects, a group/category of services, a folder, or everything at once. NOT for a single project (use document-process) and NOT for the unified system overview (use document-overall)."
---

# Document Section Skill

Document a defined **slice** of the codebase by orchestrating `document-process` across every target
in that slice, with depth-tiered output, prioritization, a resumable coverage ledger, and a
theme-deduplicated batched checkpoint so the user answers a handful of questions rather than one per
project.

> This is tier 2 of three: `document-process` (one project), **`document-section`** (a
> slice), and `document-overall` (the flow-synthesis manager and freshness actuator). The
> `document-concerns` skill owns the concern-ledger rules; this skill only flags (Phase E.7).

## Model and effort

Use **Sonnet 4.6 at high effort** for this skill. The orchestration work (ledger updates, batching
checkpoints, priority sorting) is structured and mechanical; the per-target documentation work is
delegated to `document-process`. Opus is not warranted here.

## Core stance

Inherit `document-process`'s cardinal rule — **a confident wrong sentence is worse than an admitted
gap** — and add three orchestration-level rules:

- **Reuse `document-process`, never reimplement it.** This skill is an orchestrator. The actual
  per-target documentation work is always delegated to `document-process` so the two cannot drift.
- **Incremental by default.** Because `document-process` has an Update mode, re-running
  `document-section` patches what drifted instead of redoing finished work. The coverage ledger is
  what makes that resumable.
- **No silent truncation.** Always report the full resolved target set and anything excluded. If a
  run is capped, sampled, or partial, say so explicitly.

## When to invoke

Trigger when the user says something like:
- "document all the `Squid.AzFn.*` services" / "document every Windows service"
- "document these projects: A, B, C"
- "document everything under `<directory>`"
- "document the whole codebase" / "document everything"

Do **not** trigger for:
- A single project/service/file → use `document-process`.
- The unified, cross-cutting system narrative → use `document-overall`.

## Inputs you need

1. **Section spec** — how the slice is defined. Accept any of: an explicit project list; a category
   (`Squid.WinSvc.*`, `Squid.AzFn.*`, core `Squid.*`, `*.Tests`); a directory; a glob; or "all".
2. **Exclusions (optional)** — only if the user names them. Default is to document everything in
   the resolved section (see Phase A).
3. **Domain context** — gathered via the batched checkpoint (Phase D), not up front.

## What to produce

- A documentation file per target at **`Documentation/sections/<SectionName>/<ProjectName>.md`** (produced by
  `document-process` at the assigned depth tier). **Match the repo's existing documentation root** if
  one exists — in this repo that is `Documentation/sections/` (the prior AzFn run wrote `Documentation/sections/AzFn/`),
  NOT a fresh `docs/` tree. Never write per-target files inside the project directories themselves;
  they all land under the single central documentation root. The section name is derived from the
  section spec (e.g., `AzFn`, `WinSvc`, `CoreLib`). The project name drops the common prefix (e.g.,
  `ContraParserSvc`, not `Squid.AzFn.ContraParserSvc`).
- A **coverage ledger** at `.claude/coverage/documentation-coverage.md`, updated with depth tier
  per target row. Open question counts use three columns: `H/L/R` (human-high, human-low,
  ref-blocked).
- A **section synthesis document** — a standing artifact at **`Documentation/sections/<SectionName>.md`** (one
  level below the master `document-overall` page, mirroring how a viz clusters a subsystem).
  This is the page a reader opens FIRST; per-target files are drill-down. It MUST contain: a short
  "how the cluster fits together" orientation paragraph (what binds these services — shared runtime,
  transport, or library), a one-line-per-service "at a glance" table linking each per-target doc, and
  a dedicated **`## Concerns Raised`** section that OWNS every cross-cutting/systemic finding (stated once here, never repeated
  in each per-target doc — the per-target docs link back to it). Also: counts, depth-tier breakdown,
  and anything excluded. Keep it to roughly one screen; it is a map, not a re-narration.

## Process — Phases

These are orchestration **Phases** (A–E), distinct from the per-target **Passes** that
`document-process` runs inside each target.

### Phase A — Resolve the target set
Interpret the section spec and produce a concrete list of targets:
- For project-based specs, **use the filesystem as the primary source**: find all directories
  matching the section spec that contain a `.csproj`. Use `AS/SquidAll.sln` as a supplementary
  index (relative paths, quick categorization) but not as a gate — a project that exists on disk
  is in scope whether or not it is registered in the main solution. Test projects in particular
  are often registered only in sub-solution files and must not be silently dropped; they are a
  primary documentation source (usage patterns, edge cases, invariants).
- Categorize each by naming convention: `Squid.WinSvc.*` (services), `Squid.AzFn.*` (functions),
  core `Squid.*` (libraries), `*.Tests` (tests), and anything else (legacy/special).
- **Include everything in the resolved section by default** — tests and non-`Squid.*` legacy
  included. Exclude a category **only** when the user explicitly asks.
- **Report the resolved list + count, and note any user-requested exclusions, before heavy work.**
  This is a cheap scope confirmation, not the domain checkpoint.

### Phase A.5 — Design checkpoint (large or first-time sections)

Before proceeding, check two conditions:
- The resolved target set is **>20 projects**, OR
- The user has not previously run `document-section` on any section (no ledger exists yet).

If either is true, offer: "Before I start, want me to run `/grill-me` on the approach? It's useful here to validate prioritization order, depth-tier rules, and exclusions before the batch begins — easier to adjust now than mid-run." If the user accepts, invoke `grill-me`. If they decline or neither condition applies, proceed immediately to Phase B.

### Phase B.0 — Load system overview context (if available)

Before initializing the ledger, check whether `Documentation/system-overview.md` exists. If it
does, read it once and extract the sections relevant to the service category being documented
(e.g., Architecture Shape > Service Types > WinSvc paragraph for a WinSvc batch, AzFn entries for
an AzFn batch, Kraken4 Relationship for any CoreLib batch). Store this as a single excerpt string.

Pass this excerpt to every `document-process` subagent in Phase C as **system overview context**.
This avoids each subagent independently loading the full file and ensures consistent framing across
the batch. If the file does not exist, skip silently — the excerpt is optional context, not a
requirement.

### Phase B — Prioritize + initialize the ledger
- **Default order:** services (`Squid.WinSvc.*`, `Squid.AzFn.*`) and public / Kraken4-facing core
  libraries first; leaf libraries and `*.Tests` last. Highest-traffic, highest-pain first.
- Create or update the coverage ledger. For each target record: category, **depth tier** (from
  Phase B.5), **mode** (create if no doc exists, update if one does), status = `pending`, and
  placeholders for open-question counts.
- **Resumability:** on a re-run, skip targets already `done` and still fresh per the ledger; act
  only on `pending` and `stale` ones.

### Phase B.5 — Classify depth tier per target
Before dispatching, assess each target's complexity and assign a depth tier. This controls how much
`document-process` produces and which passes it runs. The classification is intentionally lightweight
— read only the `.csproj` and file list, not source:

- **Brief**: a genuine trigger-wrapper or throwaway — ≤2 source `.cs` files, no Kraken4
  `ProjectReference`, AND **no substantial first-party `Squid.*` service library behind it**. Most
  `Squid.AzFn.*` trigger wrappers qualify. A scratch/experiment project qualifies.
- **Standard**: 3–10 source files, real logic but bounded scope, limited or no Kraken4 exposure.
- **Detailed**: Kraken4-facing API surface (e.g. a NetMQ/WCF request-response server), complex state
  machine, high operational risk, or >10 source files with non-obvious interactions.

**Thin-host caveat (do not tier on local file count alone).** A `Squid.WinSvc.*` host is typically a
2-file `Program.cs`+`Worker.cs` shell that delegates all logic to a referenced first-party library
(e.g. `Squid.MarketDataSvc`). File count would wrongly mark it Brief. For any host that delegates to a
substantial `Squid.*` service library, **inspect that library's `.csproj`/role** and tier on IT:
Standard minimum for a production host; Detailed if the library exposes a NetMQ/WCF server surface or
reaches Kraken4. Never assign Brief to a live production host just because its own directory is thin.

When borderline, go one tier higher — easier to trim than to discover a gap later. Record the tier
in the ledger.

### Phase C — Document each target (core loop, parallel)

**Brief-tier targets are not dispatched to `document-process` and do not get individual files.**
Their project name, purpose (one sentence from Pass 1), and any open questions are collected inline
and folded directly into the Phase E section summary. The synthesis entry in the section doc is the
complete documentation for a Brief-tier project. Record their ledger status as `done` with doc path
`<SectionDoc>.md (synthesis only)`.

For Standard and Detailed tier targets, dispatch `document-process` per target via subagents, in
waves that respect the Task tool's concurrency limit. Each subagent is instructed to run
`document-process` in **autonomous mode** with:
- The **depth tier** assigned in Phase B.5 (skip Pass 0.5 — tier is already known).
- The **output path**: `Documentation/sections/<SectionName>/<ProjectName>.md`.
- The **create or update mode** per the ledger.
- **System overview context** — the relevant excerpt extracted in Phase B.0, if available. The
  subagent uses this in Pass 0 without reloading the full file.
- **Skip the interactive checkpoint** (Pass 6). Do not prompt the user from inside a target.
- **Never reproduce secret VALUES in a doc.** If a target commits a key, password, connection string,
  or private key, reference it by config-key name + file location and flag it as a finding — do NOT
  copy the literal value into the markdown. The doc must not become a secret-bearing artifact. (A
  committed secret is a cross-cutting finding: route it to the section doc's `## Concerns Raised`.)
- **Return ONLY the structured object**, no prose preamble — the orchestrator parses it. (Observed
  drift: subagents wrapping the JSON in narrative. If dispatched via Workflow, use the `schema`
  option to force this.)
- The template (`README-template.md`) is now lean by default (what / how / use + gotchas + gaps +
  open questions). **Tier controls DEPTH, not which sections exist**, so every tier uses the same
  section order:
  - **Standard:** the lean template as-is. Keep "How it works" to the essential path and "How to
    run / use it" to the config/deploy that matters. Thin-host docs should land well under a screen.
  - **Detailed:** same sections, but "How it works" and "How to run / use it" carry the extra depth
    (state machine, protocol surface, API entry points for libraries). Still no re-narration.
- **Return structured output:** `{ status, mode, tier, outputPath, openQuestions[] }`, where each
  open question carries a one-line reason and a **relevance tag** (high / low — see Phase D).

Update the ledger as each target finishes (`done` / `failed` / `skipped`).

### Phase D — Theme-deduplicated batched checkpoint
This is the mechanism that makes section-scale documentation tractable.

**Step 0 — Partition by resolution type.** Before any grouping, split the accumulated open
questions into two pools:
- **`[ref:...]` questions** — do not present these to the user. Route them to Phase F for
  automatic backfill once the referenced projects are documented.
- **`[human]` questions** — these proceed through the theme and threshold logic below.

The Phase D threshold and checkpoint operate only on the `[human]` pool.

**Step 1 — Theme extraction.** After each wave completes (or at the end), group all accumulated
`[human]` open questions by recurring pattern before presenting anything to the user. A *theme* is
the same root cause appearing in 2+ projects. Name it plainly: "Committed plaintext secrets in
appsettings.json (12 projects)", "Cron timezone not verified — UTC vs Eastern (9 projects)".
Questions that don't match any theme are *project-specific*.

**Step 2 — Mid-run threshold.** Track the count of **distinct unresolved themes** (not raw question
count). When it reaches **3 themes**, pause and prompt — one theme-level answer resolves the same
question across many projects at once. Never interrupt for fewer than **2 themes**.

**Relevance criteria for open questions:**
- **High** = blocks correct understanding or carries risk: what the thing fundamentally does,
  prototype-vs-production status, who consumes it, a financial-accuracy or security ambiguity, a
  contradiction between code and existing docs.
- **Low** = cosmetic or nice-to-know: a minor naming nuance, an untuned parameter, a stylistic
  question.

**End-of-section checkpoint:**
- **"Needs your input"** block: the themes (max ~5–6), each with a name, affected project count,
  and the single question whose answer resolves it for all of them. Then the project-specific
  high-relevance questions (usually few).
- **"Also open (lower priority)"** list: one line per low-relevance question, opt-in only.
- Fold answers back: apply each resolved theme across all affected targets' docs. Update ledger
  open-question counts.

**Cross-cutting findings** — a theme that represents a systemic issue requiring action (not just a
domain answer — e.g., committed secrets, a systematic misconfiguration) — are surfaced as a
dedicated callout in the Phase E section summary, not duplicated in each per-target doc.

### Phase E — Section summary + finalize ledger
- Write final ledger statuses and depth-tier breakdown. Open question counts use `H/L/R` (human-high
  / human-low / ref-blocked) per target row.
- Write (or update) the **section synthesis document** `Documentation/sections/<SectionName>.md` (see *What to
  produce*). It covers:
  - The "at a glance" table: one line per service, linking its per-target doc.
  - **`## Concerns Raised`** — the systemic/cross-cutting findings, stated ONCE here for the whole
    section. This is the section's most important content; every finding that recurs across 2+
    targets belongs here, not duplicated in the per-target docs.
  - Counts: documented / updated / skipped / failed, with per-tier breakdown.
  - Remaining lower-priority `[human]` questions, `[ref:]` backfill count, and what was excluded
    (no silent truncation).
- **Brevity is a hard requirement, not a nicety** (the user is information-overload sensitive). Push
  every cross-cutting finding UP into `## Concerns Raised` and leave only a one-line back-pointer in
  the per-target docs. Enforce the Phase C section-omissions so Standard docs stay lean. Target the
  synthesis doc to ~one screen and Standard per-target docs to well under a screen. Less text wins.

### Phase E.7 — Flag new concerns for reconciliation (replaces the retired E.5/E.6)
The master overview and the concerns ledger are no longer touched by this skill (single source of
truth: `document-overall` owns the master and the section→master edge; `document-concerns` owns the
ledger rules; `document-overall` Phase 6 reconciles). On a run that surfaces a NEW concern:
- APPEND one row per concern to the pending-flag queue `Documentation/concerns-pending.md`
  (create-if-missing with the header row):
  `| Date | Source (skill/run/audit row) | Affected project or doc (path) | Concern (one line) |`
- Producers append only — never write `concerns-ledger.md` or `system-overview.md` directly.
  `document-overall`'s next run sweeps the queue, reconciles through `document-concerns` (dedup,
  ledger entry, back-links), and empties it.
- The per-section `## Concerns Raised` stays put — it is the section-local view and the per-target
  back-link target. The canonical concern model is stated once, in `document-concerns/SKILL.md`.
- **Never reproduce secret VALUES** — reference by config-key name + file location, same rule as the
  docs.

### Phase F — Automatic backfill (cross-reference resolution)
Runs automatically after Phase E, without user prompting.

**Step 1 — Identify newly resolvable refs.** For every project newly marked `done` in this run,
scan the full coverage ledger for any existing `done` docs that contain `[ref:<ProjectName>]`
open questions pointing to it.

**Step 2 — Dispatch targeted updates.** For each affected doc, dispatch a `document-process`
Update mode subagent with:
- The newly-documented project's doc as explicit context.
- The specific `[ref:]` open questions to resolve.
- Instruction: resolve the ref questions, convert them to verified statements, and patch only those
  sections. Do not touch anything else in the doc.

**Step 3 — Update the ledger.** Decrement the R count for each affected target row. If R reaches 0,
remove the column value.

**Step 4 — Report.** "Backfill resolved N ref-questions across M docs." List the affected docs and
which ref questions were closed. If any ref targets are not yet in the ledger (not yet documented),
list them so the user knows which future section runs will trigger further backfill.

## Configurable defaults
- **Concurrency:** dispatch in waves; respect the Task tool's concurrency limit.
- **Theme threshold:** prompt mid-run at **3 distinct unresolved `[human]` themes**; never below
  **2**. `[ref:]` questions do not count toward this threshold.
- **Backfill:** runs automatically after Phase E; no user opt-in required.
- **Exclusions:** none by default. A category is excluded only on explicit user request.

## Coverage ledger
- **Location:** `.claude/coverage/documentation-coverage.md`. One ledger for the repo,
  appended/updated across runs.
- **Format:** see the bundled `coverage-ledger-template.md`. Per-target row:
  `Project | Category | Tier | Mode | Status | Doc path | Open Qs (H/L/R) | Last run`.
  H = human-high, L = human-low, R = ref-blocked (pending backfill).
- The ledger is the source of truth for resumability and progress visibility across the ~300
  projects.

## Pitfalls
- **Don't reimplement documentation logic here.** If you find yourself reading a target's source to
  write its doc directly, stop — that work belongs to `document-process`. This skill orchestrates.
- **Don't prompt from inside a target.** All user interaction happens in the Phase D batched
  checkpoint, never per-project mid-run (except the single mid-run threshold prompt).
- **Don't count raw questions for the threshold.** The threshold tracks *distinct unresolved
  `[human]` themes*, not raw question count. A single theme touching 13 projects is one theme, not
  13 questions. `[ref:]` questions are not counted at all.
- **Don't route `[ref:]` questions to the user checkpoint.** They resolve automatically via Phase F
  when the referenced project is documented. Presenting them to the user conflates "we don't know"
  with "we haven't looked yet."
- **Don't duplicate cross-cutting findings across docs.** Committed secrets or systematic
  misconfigurations belong in the Phase E section summary, not in every affected per-target doc.
- **Don't silently skip targets.** Anything excluded, failed, or deferred is reported in Phase E.
- **Don't redo finished work.** Honor the ledger — fresh `done` targets are skipped on re-runs.
- **Don't broaden to synthesis.** Cross-cutting narrative is `document-overall`, not this skill.
