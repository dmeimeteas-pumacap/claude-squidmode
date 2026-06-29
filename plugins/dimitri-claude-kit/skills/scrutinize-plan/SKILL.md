---
name: scrutinize-plan
description: "Adversarially critique a PLAN, DESIGN, or PROPOSED APPROACH before the work is done — INCLUDING implementation/coding plans and architecture designs. Runs an INDEPENDENT critic that sees only the plan, not the design discussion, and returns a structured teardown (unfounded assumptions, inverted dependencies, missing scope, sequencing errors, single points of failure, verification gaps) with a PROCEED/PROCEED-WITH-FIXES/REWORK verdict. Use on '/scrutinize-plan', 'scrutinize this plan', 'critique this plan', 'review this plan', 'red-team this plan', 'find the holes in this plan/approach', 'critique this design/approach before I build it'. Distinguished by TIMING: this reviews the PLAN FOR work not yet done; code-review/security-review review work ALREADY written. NOT grill-me (that interrogates a plan interactively while it's still forming)."
user-invocable: true
argument-hint: "[path to plan .md]  (else snapshots the plan from the conversation, or uses the newest in ~/.claude/plans/)"
---

# Scrutinize-Plan Skill

Run an **independent adversarial critique** of a completed plan or design document, before it's
committed to. The capability this systematizes: a fresh reviewer who has seen *only the artifact*
(not the conversation that produced it) catches plan-breaking errors that the author — anchored in
their own reasoning — cannot. That independence is the entire point.

**Distinct from neighbors — the axis is TIMING, not subject matter:**
- `grill-me` — interrogates a plan *interactively, while it's forming*. Collaborative, real-time.
- `code-review` / `security-review` — review work **already written** (code/diffs).
- `scrutinize-plan` — reviews the **plan for work not yet done**, in *any* domain: an
  implementation/coding plan, an architecture design, a technical approach, a process. A coding plan
  absolutely belongs here — "it's about code" does NOT route it to `code-review`; "the code already
  exists" is what routes there.

## When to invoke
Model-invocable on plan-critique phrasing, or called manually: `/scrutinize-plan`, "scrutinize this
plan", "critique this plan", "review this plan", "red-team this plan", "tear this plan apart", "find
the holes in this plan/approach", "critique this design/approach before I build it". The thing under
review is always a **forward-looking plan/design** (including an implementation plan for code), never
already-written code.

## Output
Chat by default: a structured critique relayed from the independent critic (see DESIGN DECISION 2 for
the optional file-write). Writes nothing to the plan itself — it critiques, never rewrites.

---

## Process

### Step 1 — Resolve the plan artifact
1. If a path arg is given, use it.
2. Else if the user is pointing at a plan/design/approach laid out in THIS conversation (common for
   implementation plans that live in chat, not a file), **snapshot it**: write the plan as stated to a
   temp `.md` (scratchpad), capturing ONLY the plan itself — not the surrounding discussion or its
   justification. Critique that snapshot. This is what preserves independence for an in-chat plan.
3. Else use the most-recently-modified `*.md` in `~/.claude/plans/`.
4. Else ask which plan. Never critique thin air.
Confirm the resolved/snapshotted path back to the user in one line before spawning the critic.

### Step 2 — Spawn the INDEPENDENT critic (the load-bearing mechanic)
Use the Agent tool (`subagent_type: Plan`, or general-purpose) to spawn ONE critic that receives
**only**:
  - the plan file PATH (it reads the file itself, fresh), and
  - the critique rubric below.
**Do NOT** pass the current conversation, the design rationale, your own summary, or any defense of
the plan. The critic must form its judgment from the artifact alone — that blindness to the design
process is the feature, not a limitation. (Single critic for v1; see DESIGN DECISION 3 for a panel.)

Critic prompt skeleton:
> Read-only adversarial review. Read the plan at `<path>`. You have NOT seen the discussion that
> produced it — judge ONLY what the document actually says. Default to skepticism: assume it has
> flaws and find them; but cite the plan's own text for every finding — never invent a problem.
> Apply the rubric. Return the structured critique format below.

### Step 3 — Apply the critique rubric
The critic evaluates the plan against these dimensions:
- **Unfounded assumptions** — claims the plan rests on without establishing; "what must be true for
  this to work that the plan never verifies?"
- **Inverted / missing dependencies** — step N needs an output of step N+M; ordering that can't
  actually execute; a prerequisite never produced.
- **Missing scope** — something the plan must address to succeed but doesn't (error paths, rollback,
  data migration, the unhappy case).
- **Single points of failure / load-bearing unknowns** — one assumption or component whose failure
  sinks the whole plan.
- **Verification gaps** — steps with no success criterion; "how would you know this step worked?"
- **Overcomplication** — a materially simpler path the plan ignored.

### Step 4 — Return the structured critique
The critic returns, and the skill relays:
- **Verdict** — one of: `PROCEED` / `PROCEED WITH FIXES` / `REWORK`.
- **Findings grouped by severity:**
  - `BLOCKING` — must resolve before proceeding.
  - `ADVISORY` — worth considering, not a gate.
  Each finding: the plan claim/text it targets · why it's a problem · a concrete suggested resolution.
- **What the plan got right** (brief) — so the critique is calibrated, not reflexively negative.

### Step 5 — Offer the next move (staged-critique seam)
After relaying, offer (do not auto-run): resolve the BLOCKING findings via `grill-me`, or revise the
plan and re-run `scrutinize-plan`. This is the brainstorm → review → revise → critique loop.

---

# Guardrails
- **Independence is sacred.** The critic gets the artifact + rubric ONLY — never the design chat, never
  a summary that pre-frames it. Violating this collapses the skill into self-review.
- **A file is required** (not an inline-pasted plan in the same chat where it was designed) — reading
  from a file is what lets the subagent come to it fresh. If only an inline plan exists, write it to a
  temp `.md` first, then critique that.
- **Critique, never rewrite.** Read-only on the plan file. The skill does not edit the plan.
- **No fabricated findings.** Adversarial stance, but every finding cites the plan's actual text. A
  weak plan with three real flaws gets three findings, not padded to ten.
- **Applies to code PLANS, not written code.** An implementation/architecture plan for code is
  squarely in scope. The boundary is timing: the PLAN for code comes here; ALREADY-WRITTEN code/diffs
  go to `code-review`/`security-review`.

# Gotchas
- No plan file resolvable → stop and ask; never critique thin air.
- Don't let it shadow `grill-me` (during-planning) or `code-review` (already-written code) — the
  description is tuned to fire on plan/design critique. If it misfires, tighten the description first.
- The critic spawned via the Agent tool inherits no chat context by design — resist the urge to
  "help" it with background; that defeats the mechanic.

# Embedded skills & callouts
- Spawns: one independent critic subagent (Agent tool). State passes via the plan FILE, not chat.
- Chains (offered, not automatic): `grill-me` to resolve blocking findings; re-run self to re-critique
  a revised plan. Part of the future staged-critique workflow.

# Memory allocation
No sub-files for v1. The rubric lives inline. (A future version could externalize the rubric to
`rubric.md` if it grows or needs per-domain variants.)

# Versioning & iteration
- Misfires vs `grill-me`/`code-review` → tighten the **description** first.
- After 5+ real runs → add `evals/` with plans carrying KNOWN planted flaws (an inverted dependency, an
  unfounded assumption) to confirm the critic still catches them.
- If single-critic misses failure modes a panel would catch → revisit DESIGN DECISION 3.

---

## DESIGN DECISIONS (resolved 2026-06-26)
1. **Invocation: model-invocable + manual** (NOT explicit-only). Fires on plan-critique phrasing
   ("review/critique/scrutinize this plan") and via `/scrutinize-plan`. The `code-review` collision
   risk was overstated — they differ by timing (plan vs already-written code), not subject matter.
2. **Output: chat-only.** A `<planfile>.critique.md` durable write is a clean later add.
3. **Single independent critic.** A 2–3 critic panel with distinct lenses (correctness / feasibility /
   simplicity) is deferred as a later upgrade.
