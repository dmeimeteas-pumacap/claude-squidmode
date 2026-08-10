---
name: eow
description: "End-of-week wrap-up for a busy boss. Scans the week's thread Log entries to surface what you accomplished, helps you pick the top 3 (and offers work you forgot), then prints an ultra-terse copy-paste block you hand to your boss. Explicit-only: runs on '/eow', 'weekly wrapup', 'weekly summary for my boss', 'end of week', 'wrap up my week'. Capturing daily state is /log; one-day synthesis is /eod; this is the week-to-boss roll-up."
user-invocable: true
disable-model-invocation: true
argument-hint: "[YYYY-MM-DD]  (any date in the target week; defaults to current week)"
---

# EOW Skill

Roll a week of work into a 3-item list a busy boss can read in ten seconds. The boss
interrupts before you finish explaining, so every line must stand alone, lead with the
outcome, and carry zero setup. Less is the goal, to the utmost degree.

## When to invoke
Explicit-only: `/eow`, "weekly wrapup", "weekly summary for my boss", "end of week",
"wrap up my week". Does not auto-fire. Daily capture is `/log`; single-day synthesis is `/eod`.

## Output
**Chat only.** A finished copy-paste block printed in a fenced code block. Writes nothing
to disk — the user pastes it into email/Teams/Slack themselves.

---

## Process

### Step 1 — Resolve the week window
Read an optional `YYYY-MM-DD` arg (any day inside the target week). If absent, use the
current week from the `currentDate` system-reminder (else `date +%Y-%m-%d`). The window is
**Monday through the resolved day** (do not project into the future). Call the window `<START>`..`<END>`.

Compute Monday on Windows:
```powershell
$d = [datetime]'<DATE>'; $mon = $d.AddDays( -(([int]$d.DayOfWeek + 6) % 7) )
"$($mon.ToString('yyyy-MM-dd')) .. $($d.ToString('yyyy-MM-dd'))"
```

### Step 2 — Gather candidate accomplishments (auto-scan)
Primary source is thread Log entries — already structured (Did/Thinking/Next) and dated.

Scan `~/.claude/threads/active/*.md` and `~/.claude/threads/done/*.md` for `### <DATE>` Log
headings where `<DATE>` falls in the window. Pull from each in-window entry:
- **Did** lines → concrete accomplishments
- Any thread that moved to `done/` this week → a shipped/closed item (high signal)
- `## Decisions` made this week → decisions worth a one-liner

Roll same-thread entries up into one candidate per thread (a week of small Did lines on one
thread is one accomplishment, not five). Note a scrap of **evidence** per candidate if cheaply
available: thread slug, a file path from a Did line, a count ("5/85 rows"). Do not go hunting —
evidence is a bonus, never a blocker.

If thread logs are thin for the window, you may fall back to `/eod <date>` reconstruction for
specific days, but prefer the direct thread scan — it is faster and already week-shaped.

### Step 3 — Merge with the user's own pick
Ask the user, in one short prompt: "What do *you* think were your top wins this week?" Take
their list. Now you have two pools: what they named, and what the scan surfaced.

### Step 4 — Recommend the top 3
Rank candidates on the same two axes the EOD's "What moved today" section uses: **progress**
(shipped/closed outranks advanced outranks merely-touched) then **impact**. Do NOT carry the
EOD's `~time · N sent` metrics into this block — they are internal effort signals, not something a
boss reads. Present compactly — a short numbered list, one line each, no essays:
- Lead with a recommended top 3 (bias toward shipped/closed work and things with evidence).
- Explicitly flag any scan-surfaced item the user did **not** mention ("you didn't list this —
  worth including?"). Surfacing forgotten work is a core job of this skill.
- If the user named something the scan can't corroborate, include it anyway but don't fabricate
  evidence for it.

Then stop and let the user confirm or swap items. Default to 3; allow up to 5 if they insist,
but nudge toward fewer. If only 1–2 real accomplishments exist, say so — do **not** pad to hit 3.

### Step 5 — Print the boss block
On confirmation, print exactly one fenced code block, nothing before or after it but a single
line telling the user it's ready to paste. Format:

```
This week:
- <outcome, one line> [<evidence — optional, terse>]
- <outcome, one line>
- <outcome, one line>
```

Line rules (the whole point of the skill):
- One line per item. Aim for ≤ 12 words. Verb-first, outcome-first.
- No preamble, no "I worked on", no rationale, no next-steps. The boss interrupts; each line
  must survive being read alone and out of order.
- Evidence is a terse parenthetical at most (a count, a file, a thread name). Omit it rather
  than stretch for it.
- No closing summary, no sign-off.

---

## Guardrails
- **Writes nothing to disk.** Output is the chat block only. Never create or modify thread
  files, logs, source, or config.
- **Never fabricate accomplishments or evidence.** Every item traces to a thread Log entry, a
  closed thread, or something the user explicitly stated. If you can't back it, don't invent it.
- **Don't pad.** Fewer than 3 real wins → report fewer and say so. Quantity is not the goal.
- No secrets, credentials, internal connection strings, or anything the user wouldn't hand a boss.
- Future-dated portion of the week is out of scope — never project work that hasn't happened.

## Gotchas
- Thread Log date format is `### YYYY-MM-DD` inside each thread's `## Log` section. Match on
  that, and respect the Monday..<END> window — back-dated entries can appear in any thread.
- A week with no in-window thread entries → say "no logged work found for <START>..<END>, list
  your wins and I'll format them" rather than printing an empty block.
- Evidence is genuinely hard for some work (Q&A, reviews, thinking). Degrade gracefully: drop
  the parenthetical, keep the line. Do not block on finding a file or commit.
- Windows: thread files are markdown under `~/.claude/threads/`; read them directly. If you ever
  need JSONL fallback, use PowerShell `Get-Content | ConvertFrom-Json` — `jq`/`node`/`python`
  are not reliably present (see the `eod` skill's gotchas).
- The boss reads three lines and starts asking questions. That is expected and fine — the block
  is a launch point for his questions, not a self-contained report. Don't try to pre-answer them.

## Embedded skills & callouts
Standalone. Reads the same thread-log data as `eod`/`catchup` but invokes nothing required.
May optionally call `/eod <date>` as a fallback for a sparse day (Step 2). Shares state through
the thread files on disk, not through imports.

## Memory allocation
No sub-files, templates, or configs. SKILL.md alone. State lives in `~/.claude/threads/`.

## Versioning
- Trigger misfires (fires when unwanted / misses a phrase) → tune the `description` frontmatter first.
- Output too long or too soft → tighten the Step 5 line rules, not the body.
- After ~5 real runs, capture any recurring miss (a thread shape the scan skips, an evidence
  pattern that helps) as a new Gotcha.
