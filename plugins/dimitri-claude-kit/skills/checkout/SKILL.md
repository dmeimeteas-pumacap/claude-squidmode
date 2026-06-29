---
name: checkout
description: "Interactive end-of-day close-out ritual — the 'store clerk / cashier' that walks you through cleaning the state of your goals/threads/thoughts before you 'leave the store'. Use when the user says '/checkout', 'check out', 'close out the day', 'close the store', 'leaving the store', 'wrap up before I leave', 'clean up before I stop', or wants an end-of-day close-out / closing-shift sweep. Distinct from /eod (that synthesizes the day, this acts on it), from /log (single-effort capture), and from /goals review (full keep/done/drop — this is a lighter done-only daily pass). NOT the janitor skill (that is automated dead-data cleanup; this is an interactive human walk-through). Explicit-only, live-session-only."
user-invocable: true
disable-model-invocation: true
argument-hint: "(no args — runs the close-out ritual against the current day)"
---

# Checkout Skill

An interactive end-of-day **close-out ritual**. You are the store clerk / cashier at the register;
the user is checking out before they leave the store. Walk them through cleaning the state of their
goals and threads (and surfacing unstored conversation work) so nothing is left half-rung-up when they
stop for the day.

Mental model: **stations 1, 2, 3, 5 are "paying" — mandatory.** The user can ring up an empty cart
(nothing done, nothing to route) but cannot skip *looking* at a station. **Station 4 (loose ends) is
the ONLY one they may bail on** — it is optional extra work, not cleanup.

This skill **orchestrates**; it does not fork mechanics. Check-offs reuse `/log done`'s tick and
`/goals review`'s done-flip. It is a **consumer** of `/eod` output, never a re-scanner of raw
transcripts.

## When to invoke
Explicit-only, live session: `/checkout`, "check out", "close out the day", "close the store",
"leaving the store", "wrap up before I leave", "clean up before I stop". Does NOT auto-fire on ambient
phrases. Capturing a single effort is `/log`; synthesizing the day is `/eod`; the full goal sweep is
`/goals review`.

## Output
- **Stations 1–3:** mutate goal/thread files via reused conventions (flip `- [ ]` → `- [x]`, append a
  `/log` entry). Each write is gated behind a user popup choice.
- **Station 5:** chat-only recap. Writes nothing of its own.
The skill itself produces no new file. All persistence is the reused write conventions firing in
stations 1–3.

---

## Process

### Step 0 — Resolve date + assert live session + freshness ("don't close an empty till")
1. Resolve `<DATE>` from the `currentDate` system-reminder if present, else `date +%Y-%m-%d`.
2. This skill is **live-session only**. It uses `AskUserQuestion` popups — there is no one to answer
   them headless. If somehow invoked headless, stop with a one-line message; do not proceed.
3. **Freshness / empty-till check.** Read `~/.claude/session-notes/eod-latest.md`.
   - **Absent** → run `/eod` to generate it (it is the prep-sheet), then continue.
   - **Stale** → compare `eod-latest.md` mtime against the newest activity (thread `.md` files +
     repo-session JSONL transcripts, EXCLUDING the home project folder (computed from `$env:USERPROFILE`) — same
     rule as `run-eod.ps1` Guard 3). If newer activity exists, run `/eod` to refresh, then re-read.
     Windows mtime check:
     ```powershell
     $eod = "$env:USERPROFILE\.claude\session-notes\eod-latest.md"
     $eodTime = (Get-Item $eod).LastWriteTime
     $items = @()
     $items += Get-ChildItem "$env:USERPROFILE\.claude\threads" -Recurse -File -Filter *.md -ErrorAction SilentlyContinue
     $homeProj = ($env:USERPROFILE -replace '[^A-Za-z0-9]','-')
     $items += Get-ChildItem "$env:USERPROFILE\.claude\projects" -Recurse -File -Filter *.jsonl -ErrorAction SilentlyContinue |
       Where-Object { $_.FullName -notmatch "\\projects\\$homeProj\\" }
     $newest = ($items | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
     if ($newest -le $eodTime) { "EMPTY-TILL" } else { "REFRESH" }
     ```
   - **Nothing changed since last eod (`EMPTY-TILL`)** → warn the user once: "Nothing's changed since
     the last eod — the till's empty, there may be nothing to close out. Run anyway?" Offer abort, but
     let them proceed. (Closing out a day where the work was already logged is a valid, clean result —
     just say so rather than inventing tasks.)
4. The refreshed/fresh `eod-latest.md` is the **prep-sheet** for all stations. Read it once now:
   "Projects touched", "Key decisions", "Work still in progress", "Tomorrow's priorities".

### Station 1 — Did-today check-offs (MANDATORY)
Goal: tick open thread `## Next` items that today's work actually finished.
1. Read open `## Next` items (unchecked `- [ ]`) across `~/.claude/threads/active/*.md`.
2. Cross-reference against the eod's "Projects touched" + "Work still in progress" + each thread's
   `## Log` Did lines for `<DATE>`. **Be smart, not literal**: surface a Next item as a *candidate*
   only when the day's evidence suggests it is actually done. **Never invent completions** — if the
   eod lists an item as still-in-progress, it is NOT a candidate.
3. If there are candidates: present a `multiSelect` `AskUserQuestion` — "These look done — tick to
   confirm." Options = candidate items + a trailing `— none done —` sentinel (the ≥2-option pad).
4. For each ticked item, apply `/log done`'s tick: flip `- [ ]` → `- [x]` in the thread's `## Next`,
   and bump that thread's `last_touched`.
5. If there are no candidates, say so plainly ("nothing to ring up here — open items are genuinely
   still open") and move on. An empty cart is a valid result.

### Station 2 — Goal done-pass (MANDATORY, done-only)
Goal: catch goal items that lag their thread (the single most valuable thing this skill does).
1. Read unchecked `### Daily` / `### Weekly` items across `~/.claude/goals/active/*.md`.
2. **Smart pre-filter (the load-bearing trick):** prioritize items whose *linked thread already marks
   the same work `[x]`* but whose *goal item still reads `- [ ]`* — that goal-vs-thread lag is the
   prime catch. Resolve goal↔thread links via `~/.claude/goals/links.tsv`. Also include goal items the
   day's eod work plainly completed. Do not dump every unchecked item — ring up what the day touched.
3. Present a `multiSelect` popup per goal that has candidates (respect caps: ≤4 questions/call, ≤3
   real items + the `— none done —` sentinel per question; split across calls if needed). Prompt:
   "Which of these are now DONE? (Untick = not done yet.)"
4. For each ticked item, apply `/goals review`'s **done-flip**: `- [ ]` → `- [x]` in place (the item
   stays as a completed record), bump the goal's `last_touched`.
5. **DONE-ONLY.** Do NOT drop, roll (`↻ N`), or re-evaluate `review_after` here — the full
   keep/done/drop sweep stays in weekly `/goals review`. This is a light daily touch.

### Station 3 — Uncaptured-work routing (MANDATORY)
Goal: nothing the user did/decided today evaporates unstored.
1. From the eod's "Key decisions" + "Work still in progress", AND from the **current live session**,
   identify work/decisions/ideas not reflected in any thread or goal.
2. Cluster them. For each cluster, present a single-select `AskUserQuestion`: file via `/log` to an
   existing thread / start a new thread / save a memory / drop. (Padding to ≥2 options is automatic
   here — there are always ≥2 routes.)
3. Execute the chosen route by invoking the matching convention (`/log` for capture; a memory file +
   `MEMORY.md` pointer for memory; thread creation per the threads convention). Drop = take no action,
   note it was consciously dropped.
4. If everything is already captured (common when the day was `/log`-ged as it went), say so and move
   on — do not manufacture items to route.

### Station 4 — Loose ends / quick wins (THE ONLY BAILABLE STATION)
Goal: offer small finishable items to knock out before leaving — but let the user walk past.
1. Surface a SHORT list (≤3) of small, finishable items: open items in the `deferred-quick-wins` goal,
   short/near-done thread `## Next` items, anything the day left one step from done.
2. Present them as an OFFER with an explicit bail: "Knock any of these out now, or leave the store?"
   (single-select popup: each quick win + a `— leave it for tomorrow —` option).
3. If the user picks an item, help them do it now. If they bail, that is expected and fine — move
   straight to station 5. **This is the only station the user may skip entirely.**

### Station 5 — Close the store (MANDATORY, chat-only)
1. Print a clean-state recap: what got checked off / routed in stations 1–3 (bulleted), and which
   stations were empty.
2. Pick the **1–3 most important goals** to carry into tomorrow as a mental bookmark — weigh priority,
   the week's commitments, and what the eod flagged. One line each, with the smallest next step.
3. End the ritual ("Store closed."). **Do NOT invoke `/today`.** Recording where the day ended and
   setting tomorrow's general intent is the **morning message's** job — deliberately not duplicated
   here.

---

# Guardrails
- **Live-session only.** Never run headless — there is no one to answer the popups.
- **Never re-scan raw transcripts.** Consume `eod-latest.md`; if it is stale/absent, refresh via
  `/eod` and let eod do the scanning. This skill is a consumer, not a scanner.
- **Never invent completions or items.** No validation bias — a Next/goal item is a check-off
  candidate only when the day's real evidence supports it. An empty cart is a valid, honest result.
- **Done-only at station 2.** Never drop, roll (`↻ N`), or touch `review_after` — that is weekly
  `/goals review`. Do not fork those mechanics.
- **Never invoke `/today`.** Intent-setting belongs to the morning message.
- **Station 4 is the only bailable station.** Stations 1, 2, 3, 5 always run (the user may take no
  action, but the station is always presented).
- **Reuse, don't fork.** Check-offs use `/log done` + `/goals review` done-flip conventions exactly;
  do not reimplement them.

# Gotchas
- **`AskUserQuestion` needs ≥2 options.** Pad every done/check-off popup with a trailing `— none done —`
  (or `— leave it for tomorrow —`) sentinel, or the call is rejected (same fix `/goals review` uses).
- **Popup caps:** ≤4 questions per call, ≤4 options per question. >3 real items in one station splits
  across questions/calls; never silently truncate — every candidate must appear in some popup.
- **PowerShell BOM corrupts files.** When editing goal/thread files or `links.tsv` on Windows, use the
  Edit tool (or ASCII/UTF-8-no-BOM) — `Out-File -Encoding utf8` writes a BOM that breaks `links.tsv`
  tab parsing (see memory `powershell-bom-breaks-json`).
- **`links.tsv` is TAB-separated.** Preserve real tabs when resolving goal↔thread links at station 2.
- **Morning / empty-till runs.** Invoked when nothing changed since the last eod, the honest output is
  "clean, nothing to close" — warn and let the user abort rather than fabricating close-out work.
- **Stale eod distorts every station.** Always pass the Step-0 freshness gate before walking stations,
  or you will close out yesterday's picture.
- (Fill in more after the first few real runs.)

# Embedded skills & callouts
- Reads: `~/.claude/session-notes/eod-latest.md` (prep-sheet), `~/.claude/threads/active/*.md`,
  `~/.claude/goals/active/*.md`, `~/.claude/goals/links.tsv`.
- Invokes: `/eod` (refresh-if-stale), `/log done` (station 1 tick), `/goals review` done-flip mechanic
  (station 2), `/log` + memory-write (station 3 routing). State passes through files, not imports.
- Does NOT invoke `/today`. Distinct from the future janitor skill (automated dead-data cleanup).

# Memory allocation
No sub-files needed — SKILL.md alone. All state lives in the existing goal/thread stores and
`eod-latest.md`; this skill reads and edits those in place.

# Versioning & iteration
- Trigger misfires (vs `/eod` / `/goals review` / `/log`) → tighten the **description** first.
- Station-2 missing real lags or surfacing noise → refine the smart pre-filter step, not the body
  wholesale.
- Output drift → add a gotcha or tighten the offending station's steps.
- After 5+ real runs → add `evals/evals.json` cases (e.g. a goal-vs-thread lag day, an empty-till day,
  an uncaptured-decision day) to guard edits.
