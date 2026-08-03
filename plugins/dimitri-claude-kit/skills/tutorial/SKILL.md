---
name: tutorial
description: "Interactive first-run onboarding for the Claude kit. Walks a newly-installed user, live and hands-on (not a doc to read), through the core continuity workflow and, if they used Claude elsewhere before, through confirming/migrating that prior setup. Bare `/tutorial` runs the full first-run flow; `/tutorial migrate` jumps straight to the migration router. Use when the user says '/tutorial', 'walk me through this', 'how do I get started', 'I just installed this', 'onboard me', or 'how do I move my old Claude setup over'. NOT for resuming an effort (/catchup), capturing state (/log), standing goals and areas (/goals), or planning the day (/today)."
user-invocable: true
disable-model-invocation: false
argument-hint: "[migrate]"
---

# Tutorial Skill (router)

Interactive onboarding for a *fresh recipient* of the kit. It teaches the kit's own tooling by
having the user DO it on live data, ending with a real, populated `<name>-claude-configuration`
thread instead of an empty board.

Base directory: `~/.claude/skills/tutorial` (installed path: `${CLAUDE_PLUGIN_ROOT}/skills/tutorial`).

## Scope (hard rules)

- Teaches **generic Claude Code tooling only**. NEVER reference any firm-specific or private
  knowledge — a separate private variant owns that.
- Only ever name commands that appear in the **Skill catalog** below, and the catalog must match the
  skills actually installed beside this file (`${CLAUDE_PLUGIN_ROOT}/skills/`). That directory is the
  runtime source of truth, because `PACKAGE-MANIFEST.md` lives one level above the plugin root and is
  therefore NOT delivered to a recipient. Never name a command the kit does not ship.
- **The rule runs both ways (inverse catalog check).** A catalog row with no installed skill points at
  a dead command; an installed skill with no catalog row is invisible to onboarding. Both are defects.
  If the two ever disagree, say so plainly rather than silently trusting the table.
- Conduct it interactively: do ONE step, then STOP and wait for the user to actually run the
  command before continuing. Never dump all steps at once, and never run the user's commands for
  them — the point is that they do it.

## Exit & opt-out (respect this at every prompt)

- At ANY prompt, if the user says "skip", "stop", "exit", "I know this", or similar, END the
  tutorial gracefully at once. Do not push.
- On exit OR on completion, offer once: "Want me to stop offering this on startup? I'll leave a
  marker." If yes, create the empty file `~/.claude/.tutorial-optout`. That marker is what the
  session-start nudge checks, so a familiar user is never nudged again. (The user can also just ask
  to "disable the tutorial prompt" at any time — same marker.)

## When to invoke
- `/tutorial` (bare → full first-run) or `/tutorial migrate` (→ migration router only)
- "walk me through this", "how do I get started", "I just installed this", "onboard me"
- "how do I bring my old Claude setup over" → migrate mode

Do NOT trigger for: resuming (`/catchup`), capturing state (`/log`), standing areas and goals
(`/goals`), day-planning (`/today`).

## Step 1 — Resolve the mode
| Argument | Mode | Follow |
|---|---|---|
| (none) | full first-run: Beat 1 → 2 → 3 | this file, top to bottom |
| `migrate` | migration router only | `modes/migrate.md`, then STOP |

## Preamble — open a bare `/tutorial` run with this (once)
Before anything else, set the frame in 2-3 sentences so nothing that follows feels arbitrary:
- **Why this kit exists.** Every Claude session starts from scratch — it doesn't remember the last
  one. This kit's whole job is continuity: it makes your work, decisions, and next steps persist so
  you (and Claude) resume exactly where you left off instead of re-explaining each time.
- **What this walkthrough does.** In a few minutes you'll create your first thread and watch the
  save-and-resume loop work end to end, then get pointed at the rest.
- **The `🐤 canary` line** (mention only if their replies show it): an optional health check from
  `CLAUDE.md` — if it ever disappears or changes, that's an early sign the context is degrading and
  you should start a fresh session. It can be removed.

## Warm-up — Make it yours (run `/theme` first)
Before the continuity mechanics, give them one quick, satisfying win that also teaches the basic
move of running a slash command. *Why:* it's instant, low-stakes personalization and confirms
commands work before anything depends on them.
- Ask them to run `/theme` and pick a look they like.
- **PowerShell note:** in the PowerShell terminal the theme options don't expand on their own — tell
  them to click into the command line (the options list) to reveal the choices.
- Wait for them to actually switch the theme before moving on — same one-step-at-a-time rule as the
  rest of the tutorial.

## Step 2 — Resolve the `<name>` for their first thread
Derive a suggested short name for the `<name>-claude-configuration` thread: use `git config
user.name` if set, else `$env:USERNAME`. Present it and let them accept or override, e.g.:
> "Your first thread will be called `<name>-claude-configuration` — the one place you track how
> you use and tweak Claude itself. I'll suggest the name from your git config; want that, or a
> different one?"
If the derived value is an unfriendly corporate ID, say so and invite a friendlier one. Wait for
their answer before Beat 2.

## Beat 1 — Orient / migrate
Read `modes/migrate.md` and run it (the "how were you using Claude before?" router). When it
returns, continue to Beat 2. In `/tutorial migrate` (standalone), STOP after the router instead.

## Beat 2 — Do (hands-on; this is the payoff)
Golden rule for this beat: **never give a command without first saying what it's for.** Each step
pairs an action with its purpose — deliver both, don't just dictate keystrokes. Frame the idea
first: "Claude forgets between sessions, so a *thread* is a running record of one effort — what you
did, why, and what's next — that keeps the memory outside any single session. `/log` writes to it;
`/catchup` reads it back. That save/resume loop is the core of the whole kit." Then walk these ONE
AT A TIME, waiting after each:

1. **Create their first thread.** *Why:* it's the durable home for one effort; without it, the next
   session starts from zero. Ask them to run `/log new "<name>-claude-configuration"` — a thread
   they'll genuinely reuse for how they set up and tweak Claude. When `/log` proposes the slug, have
   them confirm; then note a file now exists under `~/.claude/threads/active/`.
2. **Log a first real entry.** *Why:* capturing *Did / Thinking / Next* preserves the reasoning,
   not just the outcome — that's what makes a cold return actually make sense later. Have them run
   `/log` and record something true right now (what they're setting up, or what they'll use Claude
   for). Point out the parts it wrote: Where-I-left-off, Next, and a dated Log entry.
3. **Catch back up.** *Why:* this is the return trip that makes logging worth it — you don't
   re-explain, you get re-briefed. Have them run `/catchup <name>-claude-configuration` and show the
   loop closing: the state they just wrote, handed straight back. Say this is exactly what returning
   days later feels like.
4. **Show the payoff.** *Why:* the board is now their cross-session memory. Point out it's no longer
   empty — the session-start banner greets them with this thread every time they open Claude.

Success check: `threads/active/` holds their thread and `/catchup` briefed it. If a step errors,
troubleshoot it before moving on — do not proceed past a broken command.

## Beat 3 — Point (name the rest, don't teach it)
Frame the tier first so it's not just a list: "Everything else builds on the thread you just made —
planning on top of it, documenting with it, wrapping up the day around it." Then read the **Skill
catalog** below: give a ONE-LINE pointer for each `highlight`-tier skill (say what it's for, not
just its name), invite them to try one, and MENTION in a single clause that the `mention`-tier
skills exist, naming two or three so the clause is concrete. Keep this short — awareness, not a
second tutorial. Then go to Beat 4.

Two things to state once, because they are invisible otherwise:
- **`/eod` and `/eow` only run when the user types them.** They are `disable-model-invocation`, so
  asking Claude to "wrap up the day" will not reach them. If the user wants them, they type them.
- **`/change-review` is not a command to try.** It is an always-on format that shapes how Claude
  presents code edits; there is nothing to run.

## Beat 4 — Continue or wrap up (always offer the choice)
The tutorial ends at a natural stopping point, but never just stop — hand the user the fork
explicitly, e.g.: "That's the core loop. Want to keep going and try one more hands-on, or head off
and start using it?"
- **Keep learning** → let them pick a `highlight`-tier skill from the catalog (or name any command
  they're curious about) and walk it hands-on in the same one-step-at-a-time style as Beat 2, on
  their real data where safe. When done, offer this same choice again so they can chain as many as
  they want.
- **Go use it** → wrap up: one encouraging line, note they can re-run `/tutorial` (or
  `/tutorial migrate`) any time, and offer the opt-out (per "Exit & opt-out").

Which skills are worth walking here will change as the kit grows — drive the "keep learning" menu
off the catalog's `highlight` tier, don't hardcode a fixed sequence.

## Skill catalog (the extensible registry — EDIT HERE to add a skill)
Beats 2 and 3 are driven by this table, so onboarding a newly-shipped skill is a one-row edit.
Rules: (1) every row MUST resolve to something installed — a directory in
`${CLAUDE_PLUGIN_ROOT}/skills/` or a file in `${CLAUDE_PLUGIN_ROOT}/commands/` (that is where `/theme`
lives) — and every installed skill should have a row, `tutorial` itself excepted; never list a command
the kit doesn't ship, and don't leave a shipped one unlisted; (2) keep the spine tiny (2-3 skills) so
Beat 2 stays hands-on, not a firehose; (3) tier
meanings: `spine` = taught hands-on in Beat 2, `highlight` = one-line pointer in Beat 3,
`mention` = named in a single clause only.

| Command | One-liner | Tier |
|---|---|---|
| `/log` | Capture where an effort stands + why (writes a thread). | spine |
| `/catchup` | Get briefed back on a thread when you return. | spine |
| `/goals` | Standing areas and their task lists, plus the status board. | highlight |
| `/today` | Pick and tick the 3-5 things you're doing today. | highlight |
| `/document-process` | Generate a README for one project. | highlight |
| `/document-section` | Document a group of projects at once. | highlight |
| `/eod` | Synthesize your whole day across efforts (you type it; Claude can't). | highlight |
| `/reconcile` | True up the stores when they drift from reality. | mention |
| `/deepclean` | Filesystem tidy-up of stale files under `~/.claude`. | mention |
| `/catchupall` | Panoramic view of every active thread. | mention |
| `/eow` | End-of-week roll-up (you type it; Claude can't). | mention |
| `/grill-me` | Get interrogated on a plan until it holds. | mention |
| `/scrutinize` | Independent adversarial critique of any subject (plan/product/idea). | mention |
| `/skill-builder` | Build your own skills. | mention |
| `/logall` | Sweep sessions you forgot to log. | mention |
| `/change-review` | Always-on: how Claude presents code edits. Nothing to run. | mention |
| `/theme` | Switch the statusline palette + base theme. | mention |

## Guardrails
- **Always pair the how with the why.** Never walk the user through an action without saying what
  it's for and what it buys them. Context and justification are the point of this tutorial, not an
  extra — a step with no stated purpose is a defect.
- Generic CC tooling only; no firm-specific content; only name catalog commands.
- Never run the user's commands for them; conduct, don't perform.
- Migration must not promise a "transfer" for the same-machine case — it's a *reveal* (data was
  already shared), not a move. Detail lives in `modes/migrate.md`.
- Never nag a returning user: the session-start `/tutorial` nudge is gated on the fresh-user signal
  AND the absence of `~/.claude/.tutorial-optout`. This skill only runs when explicitly invoked or
  model-invoked on clear onboarding phrasing.

## Gotchas
- `/tutorial` is only loadable AFTER a Claude Code restart post-install — the entry points say so,
  this skill assumes it's already loaded.
- The catalog is the single source of truth for what the tutorial names. If a skill is removed from
  the kit, remove its row here too, or Beat 3 will point at a dead command. The reverse also bites:
  a shipped skill with no row never gets mentioned, which is how `/today`, `/reconcile`, and
  `/deepclean` stayed invisible after they shipped. Check both directions against
  `${CLAUDE_PLUGIN_ROOT}/skills/` **and** `${CLAUDE_PLUGIN_ROOT}/commands/` — not every shipped
  command is a skill (`/theme` is a command file), so checking only `skills/` reports false defects.
- `PACKAGE-MANIFEST.md` sits at the repo root, ABOVE the plugin, so recipients never receive it. Do
  not cite it as something the model can check at runtime.

## Maintenance — adding a skill to onboarding
1. Ship the skill (add it to the build allowlist in `build-package.ps1`, and to `PACKAGE-MANIFEST.md`
   for the repo-side record).
2. Add one row to the Skill catalog with the right tier. That is the whole change — Beats 2/3 read
   from the table, no prose edits needed.
