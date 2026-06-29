---
description: "Produce a README-style document for a single existing project, service, or process. Use when the user asks to document a specific project/service/process, write or generate a README for it, explain what an existing component does, or capture how a service works. NOT for documenting a section of the codebase or multiple projects at once (use document-section) and NOT for the unified system overview (use document-overall)."
---

# Document Process Skill

Produce a clear, accurate, README-style document for **one** existing project, service, or process.

> **Status: provisional starting point.** In-house conventions for authoring skills are not settled yet. Treat this skill's structure as a reasonable default, not a fixed standard — expect it to be revised once those conventions exist. Two companion skills are planned and out of scope here: `document-section` (batch documentation across a defined subset or the full codebase) and `document-overall` (unified system overview synthesized from per-process docs and external resources).

## Model and effort

Use **Sonnet 4.6 at high effort** for this skill. The work is structured documentation — read code, infer purpose, write accurately, flag gaps — which is well within Sonnet's range at high effort. Opus is not needed. High effort (not medium) is correct because the cardinal rule below rewards careful generation over speed.

## Core stance

The cardinal rule is: **a confident wrong sentence is worse than an admitted gap.** Document what the code actually does, verify every claim against source, and surface uncertainty as questions for the user rather than asserting it as fact. Existing comments, READMEs, and commit messages are *claims to be verified*, never sources of truth on their own.

## When to invoke

Trigger when the user says something like:
- "document the `<Project>` project / service"
- "write a README for `<Project>`"
- "what does `<Project>` actually do — capture it"
- "generate docs for `<Project>`"

Do **not** trigger for:
- "document the whole codebase" / "document everything" / a defined subset of projects → use `document-section` instead.
- Documenting code being newly written in this same session → ordinary inline work, not this skill.

## Inputs you need

1. **Target project** — the project name or path. If ambiguous, locate it before starting.
2. **Output location** — default is a `README.md` at the project root. Confirm only if the user has a different convention in mind.
3. **Domain context the code can't reveal** — gathered via the Pass 6 checkpoint, not guessed up front (e.g. what an acronym means, business cadence, downstream consumers).

## What to produce

A single `README.md` at the project root (default), following `README-template.md` **section-for-section, in order**. The fixed structure is deliberate: it is what lets the `document-overall` skill mechanically harvest the same sections from every project.

Always include both the **Open questions / for domain owner** section and the **Known gaps / future work** section. Keep them distinct: open questions are genuinely unanswered items that need a human; known gaps have answers but the work isn't done. An empty Open-questions section ("None outstanding") is a good outcome — do not pad it with future-work items; those belong in Known gaps.

## Modes: create vs. update

Before starting any passes, check whether a README already exists at the output location.

- **No README** → **Create mode.** Run all passes (0–7) as described below.
- **README exists** → **Update mode.** Run the abbreviated update process instead (see Update mode below). Do not re-derive the whole document from scratch — that discards verified work and wastes effort. The existing README is the primary frame; the job is to find what has drifted and patch only that.

The one exception: if the existing README is clearly not structured to the template (missing standard sections, appears to be a hand-written stub with no real content), treat it as raw commentary in Pass 0 and proceed in Create mode.

---

## Process — Create mode

Work the passes in order. Passes 0–4 build the draft, Pass 5 is a self-revision, Pass 6 is the user checkpoint, Pass 7 is the final pass.

### Pass 0 — Gather existing commentary (and distrust it)
Before reading for comprehension, deliberately collect everything already written about this project. This pass frames the subsequent read — the depth of Passes 1–3 should scale *inversely* with how trustworthy Pass 0 turns out to be. Rich, accurate commentary means the comprehension passes become verification rather than re-derivation.

Collect from:
- Inline comments and doc comments — especially ones explaining *why*, encoding a hard-won lesson, or warning about a pitfall.
- Any existing `README`, design note, or wiki/doc link in or near the project.
- Project-level documentation directories (`.claude/`, `docs/`, wikis, etc.).
- Commit messages and, where useful, `git blame` / commit dates on key files.
- Any known downstream consumers of this project's public surface.

Apply this discipline to everything collected:
- **Verify, don't propagate.** Each existing claim must be confirmed against current code before it survives into the new doc.
- **Weigh recency.** Compare comment/doc dates against the code they describe. A comment older than the logic it narrates is a red flag, not a citation.
- **Reconcile contradictions explicitly.** When a comment, a README, and the code disagree: **code wins**, and record the discrepancy.
- **Preserve intent even when mechanics are stale.** A comment's *why* may be worth carrying forward as "intent per original author; mechanics have since changed," flagged as such.
- **Never launder uncertainty into fact.** Anything unconfirmable from code becomes an open question (Pass 6), not an assertion.

### Pass 1 — Orient
Read the project descriptor file (`.csproj`, `pyproject.toml`, `requirements.txt`, `package.json`, `Cargo.toml`, etc. — whatever the ecosystem uses): project type, target runtime/framework, declared dependencies, and references to other internal packages or projects. Form an explicit hypothesis from the name and record it — then confirm or kill it against the code.

### Pass 2 — Trace the shape
Find the entry point and follow the main flow once, end to end, at a high level. Answer:
- **Input** — where does data come from (file, database, queue, RPC, blob, external API)?
- **Transformation** — what does it do to that data?
- **Output** — what does it produce, and who/what consumes it?
- **Config/secrets** — what configuration values does it read and from where (env vars, config files, a secrets manager, hardcoded constants)?

### Pass 3 — Find the non-obvious
Capture:
- Edge cases, ordering/timing assumptions, dedup logic.
- Error handling and failure modes.
- **Hardcoded environment-specific values** — flag these explicitly and surface them to the user; do not silently document around them.
- Threading/concurrency assumptions, idempotency, retry behavior.
- Documented-but-incomplete handling (known gaps the authors themselves flagged).

### Pass 4 — Draft against the code, then verify
Fill in `README-template.md`. Then re-read the relevant source once more and confirm **every** claim. Anything not verifiable from code alone goes into **Open questions** — never stated as fact. Items that have answers but are incomplete go into **Known gaps / future work**.

### Pass 5 — Self-revision (before involving the user)
Re-read the draft as a whole for clarity, conciseness, and simplicity:
- Cut redundancy and restated-obvious lines; tighten wording.
- Verify the ordering reads coherently and Purpose / How it fits in are genuinely skimmable.
- Confirm Open questions and Known gaps are cleanly separated — no future-work items in the questions section, no unanswered questions in the gaps section.

Keep this light — it is a polish pass, not a rewrite. Its job is to make Pass 6 a review of something already coherent.

### Pass 6 — User checkpoint (questions + product review)
Present to the user, together:
1. **What the documentation concluded** — a short summary of the project's purpose and shape.
2. **The open questions** — domain items the code couldn't resolve (use `AskUserQuestion` for crisp, decidable ones; list the rest plainly).
3. **The draft itself** for general feedback.

Their answers feed Pass 7. Do not skip this checkpoint — domain knowledge (acronyms, cadence, consumers, prototype vs. production status) lives with the user, not the code.

### Pass 7 — Final pass
Fold the user's answers and feedback in: convert resolved open questions into verified statements in the appropriate sections, apply requested changes, one last clarity read. Anything still unresolved stays in **Open questions**. Point the user to the finished file with its path.

---

## Process — Update mode

Used when a template-structured README already exists. The goal is a **targeted patch**, not a rewrite.

### Update Pass 0 — Assess the existing README
Read the README in full. Note:
- Its apparent age relative to the code (use `git log --oneline -1 README.md` vs `git log --oneline -5 <source files>` to get a rough sense of drift).
- Any sections that look stale, incomplete, or that explicitly flag known gaps / open questions still unresolved.
- Anything in **Known gaps / future work** that has since been addressed — those should graduate into the relevant sections.

This pass determines the *scope* of the update. If the README looks recent and the code changes are narrow, the update may only touch one or two sections.

### Update Pass 1 — Identify what has changed
Compare the current code against what the README describes. Focus on:
- New or removed dependencies, config keys, or entry points.
- Behavior changes in the main flow, error handling, or concurrency model.
- Hardcoded values that have moved, changed, or been flagged as a problem.
- Known gaps that are now resolved, or new ones that have appeared.

Use `git log` and `git diff` on the relevant source files if helpful. You are looking for *delta*, not re-reading the whole codebase.

### Update Pass 2 — Patch the affected sections
Edit only the sections the delta affects. Preserve all unchanged content verbatim — do not reword sections that are still accurate just to leave a mark. Resolve any items in **Known gaps / future work** that are now done by moving the content into the appropriate section as a verified statement. Add new gaps or questions if the changes introduce them.

### Update Pass 3 — Self-revision + user checkpoint
Same as Create mode Passes 5 and 6 combined:
- Re-read the patched README as a whole; confirm it still reads coherently after the edits.
- Present the user with: what changed, any new open questions, and the updated doc for review.

### Update Pass 4 — Final patch
Fold in any user feedback, then write the file. Point the user to the path.

---

## Pitfalls

- **Don't trust comments or old READMEs as fact** — verify against code; reconcile conflicts in code's favor and record them.
- **Don't guess domain meaning** — acronyms, business cadence, and "who consumes this" go to the Pass 6 checkpoint, not into assertions.
- **Don't skip the self-revision (Pass 5)** — handing the user an unpolished draft wastes the checkpoint.
- **Don't silently absorb hardcoded env values** — surface them.
- **Don't deviate from the template's section order** — uniformity is what makes the `document-overall` skill possible.
- **Don't over-document trivial leaf code** — depth belongs on the non-obvious (Pass 3), not on restating obvious getters.
- **Don't conflate gaps with open questions.** *Known gaps / future work* holds resolved-but-incomplete items (documented limitations, untuned params, maturation steps). *Open questions* holds only genuinely-unanswered items needing a human. An empty Open-questions section is a good outcome — don't pad it with future-work items.
- **Don't broaden scope to other projects** — one project per run; multi-project work belongs to `document-section` and cross-project synthesis to `document-overall`.
- **In update mode, don't rewrite what hasn't changed.** Rewording accurate, verified content just to make an edit is noise — it introduces diff without value and risks subtly altering meaning. Touch only what the code delta actually invalidates.
- **Don't skip mode detection.** Running Create mode on a project that already has a good README throws away verified work. Always check for an existing README first.
