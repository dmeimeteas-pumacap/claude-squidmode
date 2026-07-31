---
name: scrutinize
description: "Adversarially critique ANY subject before committing to it — a plan/design, a shipped product or its direction, a project, an idea mid-brainstorm, a claim, or a document. Runs an INDEPENDENT critic (blind to the discussion that produced the subject) and returns a structured teardown with a PROCEED / PROCEED-WITH-FIXES / REWORK verdict + BLOCKING/ADVISORY findings. Selectable STANCE via --lens: general (default), premortem (assume it failed, find why), devils-advocate (argue the opposing case), multi-lens (stakeholder angles). Selectable acceptance DEPTH via --depth: rough|general|specific|implementation, a cumulative ladder where findings deeper than the declared depth are out of scope, making a clean PROCEED reachable; asks for the depth when unspecified. Use on '/scrutinize', 'scrutinize this', 'critique this', 'red-team this', 'poke holes in this', 'find the holes in this idea/product/project/approach', 'play devil's advocate', 'do a premortem', 'steelman the opposite'. Distinguished by TIMING + LEVEL: reasoning/design/direction-level critique of a subject, NOT line-level bug hunting in already-written code (that is code-review / security-review), and NOT interactive interrogation while a plan forms (that is grill-me)."
user-invocable: true
disable-model-invocation: false
argument-hint: "[<target: file | 'this' | topic>] [--lens general|premortem|devils-advocate|multi-lens] [--depth rough|general|specific|implementation]"
---

# Scrutinize Skill

Run an **independent adversarial critique** of any subject before it's committed to. The capability:
a fresh critic who has seen *only the subject* (not the reasoning that produced it) catches flaws the
author — anchored in their own thinking — cannot. That independence is the entire point.

**Subject-agnostic.** The thing under review can be a plan or design, a shipped product or its
direction, a project, an idea raised in brainstorming, a claim, or a document. It is NOT limited to
plans (this skill was formerly `scrutinize-plan`; the `-plan` scope was the artificial limiter).

**Distinct from neighbors — the axes are TIMING and LEVEL, not subject matter:**
- `grill-me` — interrogates something *interactively, while it's forming*. Collaborative, real-time.
- `code-review` / `security-review` — **line-level** bugs/security in code **already written**.
- `scrutinize` — **reasoning/design/direction-level** critique of a subject, in any domain. "It's
  about code" does NOT route a coding plan to `code-review`; "the code already exists and I want bugs
  found" is what routes there.

## Lenses (the stance — `--lens`)
- **general** (default) — the standard adversarial teardown against the rubric below.
- **premortem** — assume it's later and this **failed badly**; enumerate the most likely causes,
  ranked, and the early signal that would have predicted each.
- **devils-advocate** — argue the strongest case **against** the chosen direction / **for** a specific
  alternative; name what would have to be true for the alternative to win.
- **multi-lens** — evaluate from distinct stakeholder angles (user / operator / maintainer / security /
  cost), one finding-set per angle. Best run as the **panel** (below) so each angle is an independent
  critic.

## Depth (the acceptance threshold, `--depth`)
How far down the critique reaches, and equally, what counts as OUT of scope. The ladder is
cumulative: passing a depth requires meeting every shallower depth's bar as well.
- **rough** - the overarching ideas/approach are sound: right problem, viable direction, no
  fatal premise.
- **general** - every aspect the subject must cover has been thought about, even if not yet
  explicitly defined or detailed in full. The test is blind spots, not detail quality.
- **specific** - everything that HAS been defined is itself sound, even if not in final,
  literal 1-1 implementation form.
- **implementation** - every aspect carries literal implementation guidelines/plans/steps, and
  those are sound.

Scoping rules (these are what make PROCEED reachable):
- Findings that only bite deeper than the declared depth are out of scope. List them as
  one-line deeper-depth notes at most; they never affect the verdict. Do not manufacture
  findings to avoid a clean verdict — if nothing BLOCKING survives at the declared depth, the
  verdict is PROCEED.
- Verdicts are depth-stamped, e.g. `PROCEED (at general)`. A pass at one depth claims nothing
  about deeper depths.
- Re-runs after changes: additions that clarify or further define existing scope leave the
  prior verdict standing (climb onward). Additions that EXPAND scope invalidate the verdict at
  that depth — re-run at the last-passed depth on the cumulative subject.
- No `--depth` given and none obvious from the ask → ask which depth before spawning (fold
  into Step 1's confirm). A quick inline conversational push defaults to **rough**.

## Weight (how heavy the pass is)
- **Inline stance** (lightweight, no subagent) — for an idea/claim/direction live in THIS
  conversation where the user wants a quick push ("poke holes", "play devil's advocate", "premortem
  this idea"). Adopt the stance directly and critique. Independence is weaker (same context) —
  acceptable for conversational/brainstorm use; say so if it matters.
- **Independent critic** (subagent, the load-bearing mechanic) — for an artifact (a file, or a subject
  worth snapshotting): spawn a critic blind to the discussion. Use when rigor/independence matters
  (plans, products, project direction, anything you'll commit real work to).

Default: a named file or a high-stakes subject → **independent**; a quick conversational push →
**inline**. The user can force either.

## Process (independent critic)

### Step 1 — Resolve the subject
1. Path arg given → use it.
2. Subject laid out in THIS conversation (idea/product/project/plan in chat) → **snapshot it**: write
   the subject as stated to a temp `.md` (scratchpad), capturing ONLY the subject itself — not the
   surrounding discussion or its justification. Critique that snapshot. This preserves independence.
3. A plan critique with nothing named → the newest `*.md` in `~/.claude/plans/`.
4. Else ask what to scrutinize. Never critique thin air.
Confirm the resolved/snapshotted target + the chosen `--lens` + `--depth` back in one line
before spawning (this is where you ask for the depth if it wasn't given and isn't obvious).

### Step 2 — Spawn the INDEPENDENT critic (load-bearing)
Agent tool (`subagent_type: Plan` or general-purpose), ONE critic receiving **only**: the subject file
PATH (it reads fresh) + the rubric + the lens instruction. **Never** pass the conversation, the
rationale, your summary, or any defense. Blindness to how the subject was produced is the feature.

Critic prompt skeleton:
> Read-only adversarial review, `--lens <lens>`, `--depth <depth>`. Read the subject at `<path>`.
> You have NOT seen the discussion that produced it — judge ONLY what the document says. Default to
> skepticism: assume flaws and find them, but cite the subject's own text for every finding — never
> invent one. Findings that only matter deeper than `<depth>` (per the depth ladder) are OUT of
> scope: list them as one-line notes, never let them shape the verdict. If no BLOCKING finding
> survives at the declared depth, the verdict is PROCEED at that depth. Apply the rubric through
> the lens. Return the structured format below.

### Step 3 — Rubric (general lens; other lenses reshape emphasis)
- **Unfounded assumptions** — what must be true for this to work that the subject never establishes?
- **Inverted / missing dependencies** — ordering that can't execute; a prerequisite never produced.
- **Missing scope / blind spots** — something it must address to succeed but doesn't (failure paths,
  rollback, the unhappy case, second-order effects).
- **Single points of failure / load-bearing unknowns** — one assumption whose failure sinks it.
- **Weak evidence** — claims asserted without support; "how do we know this?"
- **Verification gaps** — no success criterion; "how would you know it worked?"
- **Overcomplication** — a materially simpler path ignored.

### Step 4 — Return the structured critique
- **Verdict** — `PROCEED` / `PROCEED WITH FIXES` / `REWORK`, depth-stamped (e.g. `PROCEED (at
  general)`).
- **Findings by severity:** `BLOCKING` (must resolve) / `ADVISORY` (worth considering). Each: the text
  it targets · why it's a problem · a concrete suggested resolution.
- **Deeper-depth notes** (optional, one line each) — observations below the declared depth;
  informational only, never verdict-affecting.
- **What it got right** (brief) — so the critique is calibrated, not reflexively negative.

### Step 5 — Panel (opt-in, higher cost — the multi-lens engine)
For a high-stakes subject or `--lens multi-lens`, escalate to the **Workflow** tool: N independent
critics in parallel, each a different lens/angle, majority gate. Only on request; default is one critic.

### Step 6 — Offer the next move (the depth ladder)
On `PROCEED` at the declared depth: if the subject is headed for implementation and the depth was
below the target, offer to climb one rung (rough → general → specific → implementation); otherwise
stop, it passed. On `PROCEED-WITH-FIXES` / `REWORK`: offer (do not auto-run) resolving BLOCKING via
`grill-me`, or revise and re-run at the SAME depth. Gate (per CLAUDE.md three-tier workflow): a plan
should hold `PROCEED (at general)` or better before scaffold/implementation; escape phrases bypass.

## Loop budget (re-scrutinize policy, added 2026-07-20)

PROCEED-WITH-FIXES is the critic's NATURAL RESTING VERDICT — it is instructed to be skeptical, so
repeat runs rarely converge to a clean PROCEED on their own. Budget the loop up front:

- **Default = light: 1–3 total passes.** One pass, fold fixes; at most two re-runs. If the user
  hasn't said otherwise, this is the budget. After it's spent, fold the remaining blockings, mark
  the subject "stamp pending re-run at pickup," and stop.
- **Extended (opt-in, for genuinely complex subjects): target 5–8, hard cutoff 10.** Past ~5,
  basic direction from the user beats more scrutiny — check in rather than continue.
- **Ask which budget when starting a fix-and-re-critique cycle** if the user hasn't indicated one.
- **Convergence test, checked every round:** if a re-run's blockings are new INSTANCES of an
  already-fixed finding CLASS (not a new class), treat the subject as converged — fold and stop,
  regardless of remaining budget. Only a genuinely new failure class justifies another pass.
- **Never silently wheel-spin:** on any round ≥3 that still returns WITH-FIXES, say so to the user
  and let them call continue/stop instead of auto-spawning the next critic.

## Guardrails
- **Independence is sacred.** Independent-weight critics get the subject + rubric + lens ONLY — never
  the discussion or a pre-framing summary. Violating this collapses the skill into self-review.
- **Snapshot in-chat subjects to a file first** for the independent weight — reading from a file is
  what lets the critic come fresh. (Inline weight skips this by design, at a stated independence cost.)
- **Critique, never rewrite.** Read-only on the subject.
- **No fabricated findings.** Every finding cites the subject's actual text. Three real flaws → three
  findings, not padded to ten.
- **Level, not topic, sets the boundary.** A coding/architecture plan or a product's direction is in
  scope; already-written code you want bug-hunted is `code-review`/`security-review`.

## Gotchas
- Nothing resolvable to scrutinize → stop and ask; never critique thin air.
- Don't shadow `grill-me` (during-forming) or `code-review` (written code). If it misfires, tighten the
  description first.
- The independent critic inherits no chat context by design — resist "helping" it with background.

## Versioning
- Formerly `scrutinize-plan` (renamed + generalized 2026-07-06): subject broadened beyond plans; added
  `--lens` stances (premortem / devils-advocate / multi-lens) and the inline vs independent weight.
- 2026-07-08: added the `--depth` acceptance ladder (rough / general / specific / implementation)
  with depth-scoped verdicts, so a clean PROCEED is reachable at a declared threshold. Absorbed the
  plan→scaffold gate from `staged-critique`, which was deleted (never invoked; its loop was just
  re-running this skill).
- After 5+ real runs → add `evals/` with subjects carrying planted flaws to confirm the critic catches
  them.
- If the panel (Step 5) gets frequent use → factor it into a saved Workflow the skill calls by name.
