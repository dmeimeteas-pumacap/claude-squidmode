# Submode: plan propose (I propose the day from prior context)

The deliberate context-FIRST style — the exception to `plan.md`'s contextless-first rule.

## 1 — Review-yesterday gate (skip when called from `yesterday` option C)

**When entered directly** (`/goals propose`, or free text that read as propose): do NOT jump straight
to a proposal. First prompt a small yes/no gate — "Review yesterday first?" — and route on the answer:

- **Yes** (the DEFAULT, and what to assume when context is thin / you do not have enough to propose a
  confident day): hand off to `modes/plan-yesterday.md` — it prints yesterday verbatim and offers its
  A/B/C menu (check off / carry over+add / propose). The proposal then happens via that menu's option C,
  which re-enters this file at **step 2** (gate already satisfied — do not re-prompt).
- **No**: proceed straight to step 2 and propose now (the original propose behavior).

**When entered from `yesterday`'s option C**: the review already happened — **skip this gate entirely**
and start at step 2. (This is what prevents a propose→yesterday→propose loop.)

## 2 — Propose the day (the proposal core)

Read the board (`board.md`'s scoped read), linked thread `## Next` items, and the latest EOD digest,
then propose a concrete day: a PRIMARY (`★`), a quick win (`▸`) if one fits, and a few tier-tagged
musts, each with its smallest next step and a one-line rationale.

Respect the board's sequencing principles (importance ≠ urgency ≠ readiness; protect the primary; do
demanding work while fresh; quick wins as momentum, not day-eaters). Give a definitive proposal with
at most one caveat — not an even-handed menu.

## 3 — Confirm + commit

Offer it for a one-reply confirm/edit (manual-first: do not commit what the user did not accept). On
confirm, hand the plan to `modes/today.md` step 3 to commit + render + mirror.
