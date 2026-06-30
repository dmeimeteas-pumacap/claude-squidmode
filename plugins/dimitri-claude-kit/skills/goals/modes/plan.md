# Mode: plan (guided generative grounding session)

**Purpose:** help the user figure out what is actually on their mind — priorities and tasks — by
asking broad grounding questions, then route what surfaces to the right place. It is a **less
pointed sibling of `new`**: `new` is laser-focused on creating one specific goal; `plan` is the open
"let's figure out what I'm carrying" session that can *lead into* `new` (durable ambitions) and into
`today` (today-scoped tasks).

**Writes nothing to the goals store directly.** Durable items get created via the `new` framework
(its own review gate). Today-scoped items get committed via `today` (which writes the task-tracker
store, `accountability/today.md`). Both happen only with the user's confirmation.

## 1 — Do NOT front-load the board
The point is generation, not review. Do NOT open the board or read goal files first — that anchors
the user to old framing. Start by prompting them to think.

## 2 — Grounding questions (broad, capped, one at a time)
Ask open grounding questions, **stopping after each** (clarification-first style). Cap at ~3-4 — the
failure mode is turning this into a planning marathon, so stop once there is enough to work with.
Pick/adapt:
- "What's on your mind right now — what are you carrying or want to make progress on? Brain-dump, don't filter."
- "Of that, what actually matters this week vs just noise?"
- "What's the one thing that has to happen today?"
- "Anything nagging that you keep putting off?"

If the user front-loads everything in the first answer, skip ahead. EF note: if they spin or
over-scope, name it lightly and pull toward "what's the ONE must" — do not let it balloon.

## 3 — Reflect + sort
Reflect back what surfaced, in the user's own words, sorted into two buckets:
- **Durable** — ongoing ambitions / multi-day efforts (goal-shaped).
- **Today** — concrete things to get done today (task-shaped).
Mark a single PRIMARY among the today bucket (the one must).

## 4 — Route (offer, do not auto-write)
- **Durable bucket → `new` framework.** For each goal-shaped item, offer to create it via the `new`
  capped interview (read `new.md`), with its dedup + review gate. Bias toward extending an existing
  goal over creating a new one. Offer, do not auto-create.
- **Today bucket → hand to `today`.** Pass the PRIMARY + today musts to mode `today` (read
  `today.md`), which commits them to the task-tracker store and shows the day's plan. This is the
  standard close of a `plan` session.

Keep routing light — a few lines, not a full board render. If the user only wanted to think out
loud, leaving everything uncommitted is a valid outcome; the reflected list still stands.
