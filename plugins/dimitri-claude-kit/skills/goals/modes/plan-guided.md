# Submode: plan guided (structure the day by effort/importance, before topics)

EF-coach framing: here you have NO awareness of the user's day-to-day topics. Help them structure
time/effort first; reconcile with real goals/threads only **after** the first pass (see `plan.md`
step 3, contextless-first).

## 1 — The menu: where does your mind want to start?
Present as a numbered text list (too many items for a popup). The user may pick any item, in any
order — you drive the sweep (step 2) until the core tiers are covered.

**Tier prompts** (each maps to a fixed board glyph, so the day shows a value gradient):
1. **▸ A quick win** to knock out first
2. **★ Your central goal / non-negotiable** for today (exactly one)
3. **● A today-must** (tackled after the primary is banked)
4. **○ A step-back / workflow-change task** (meta work, not the grind)
5. **◇ Something optional** that'd be nice to land
6. **◐ An earned break** (lower-stakes step-away, e.g. tooling polish)
7. **▽ Backburner** — something explicitly parked this cycle

**Other lenses (NOT part of the mandatory sweep):**
8. **Split by energy** — what wants your full morning focus, what fits the midday slump, what suits
   the late-day resurgence. Produces morning/midday/late buckets; does not force the tier sweep.
9. **Something you can't prioritize yet** — note it and keep track of it, and help place it once
   you've shared more, unless you feel immediately/strongly confident about where it goes.

**Escape hatches (reminders if you got here and still don't know what you want):**
- → `propose`: "I really don't know — give me options based on prior goals and where I left off"
  (read `modes/plan-propose.md`)
- → `dump`: "I can't pick a start, but I've got lots of ideas in mind" (read `modes/dump.md`)
- → `brainstorm`: "Let's just talk, no assignments yet" (read `modes/plan-brainstorm.md`)

## 2 — Mandatory sweep + counter
Ensure the day gets a gradient, not one lone priority. **Require ≥1 item for each CORE tier:**
`▸` quick win, `★` primary (exactly one), `●` must, `○` step-back. The **lower-weighted** tiers
(`◇` stretch, `◐` break, `▽` backburner) are optional — **prompt for one anyway, accept a skip.**

Track progress with a **counter**, not by hiding picked prompts — after each pick, show e.g.
`core tiers: 2/4 set  (▸ ✓ · ★ ✓ · ● … · ○ …)`. Keep asking until the 4 core tiers are set (or the
user explicitly bails to an escape hatch). The mandatory sweep does NOT apply while the user is in
the split-by-energy or can't-prioritize-yet paths — those are free-form.

## 3 — Reconcile (after the first contextless pass)
Once an initial plan is drafted, reconcile against active goals (`board.md`'s scoped read) + linked
thread `## Next` items + the latest EOD digest — to catch anything important that was dropped and to
merge picks with existing goals for continuity/progress. Surface additions as a short confirm; do not
silently inject.

## 4 — Commit
Hand the confirmed primary + tier-tagged musts to `modes/today.md` step 3 (the day-store write with
glyph tags + the goal-map sidecar) — do not write the store directly here. `today` renders it back
with the legend and refreshes any optional mirror.
