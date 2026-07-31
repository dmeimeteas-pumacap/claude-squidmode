# Goals — shared reference (loaded by write modes: new, dump, review, manage; and /today's write-back)

## Store layout

```
~/.claude/goals/
  goals.md             # THE single action/planning store: every area + its tasks (format below)
  links.tsv            # junction: area-id <TAB> thread-slug <TAB> relevance
  done/<id>.md         # retired areas, one extracted file each (kept readable)
```
(The author install also carries a frozen `archive-per-area/` migration backup — historical,
not part of the store contract; a fresh install never has it.)

An AREA (= what used to be called a goal) is a `## ` section of `goals.md`: a tag + optional
north-star + its own list of actionable tasks. **Tasks live HERE, not in threads** — threads are
MEMORY; a thread `## Next` item is an alignment pointer, not the backlog. `/reconcile` cross-checks
the two (surface divergence only, never auto-sync).

`id` = the kebab key on the area's metadata line — it is the `links.tsv` key and stays stable even
when the heading is reworded. Junction relevance ∈ {`primary`, `supporting`, `tangential`}. The
junction is the **single** store of area↔thread edges; per-thread `goal:` frontmatter stays `null`.

**No `INDEX.md`.** Areas are few; the board (bare `/goals`) is the live dashboard.

## Area format (inside `goals.md` — load-bearing)

```markdown
## <Area title>
id: <kebab-id> · prio: <n> · review_after: <YYYY-MM-DD|null>
live_progress: `<command>` → `<regex, 2 capture groups = done/total>`   (optional line)
thread: [[<slug>]] · [[<slug>]]                                          (optional line)
north-star: <1-2 lines, the big-picture "why".>
- [ ] <actionable task> {deadline:YYYY-MM-DD | this-week | evergreen} ↻ N (since MM-DD)
  > <optional guardrail/note for the task above>
```

- `prio` is numeric, lower = higher (1 = top).
- Every task carries ONE timeliness tag `{deadline:… | this-week | evergreen}` — a selection aid for
  `/today`'s pick, not a scheduler.
- `↻ N` = rollover count, space before N (`↻ 3`, never `↻3`) — in the store AND anywhere rendered.
  Set/bumped only by `review`'s keep-roll. A task rolled ↻ 4+ is a signal (the drift engine flags it).
- The north-star is optional but fight to keep it — without it the store degrades into the flat
  tagged to-do list that did not stick before.
- Completion: flip `- [ ]` → `- [x]` in place (the completed record stays in the list). Retiring a
  whole AREA = extract its section to `done/<id>.md` (see `manage`) — never delete history.
- Deliberation/history stays in the linked thread, not here. An area may map 1:1 to a thread, span
  several, or have none (e.g. the sales book).

## Guardrails

- **Single-writer.** `goals.md` owns areas + tasks; `links.tsv` is the sole edge store; threads own
  `## Next`. Never duplicate an edge into thread frontmatter; never move a task into a thread.
- The board writes **nothing**. `/today` writes the day store (`accountability/today.md`), its
  goal-map sidecar, and the write-back tick here (checkbox flips only — never task text).
- `review` and the bare `done` sweep are interactive only — never run headless.
- `dump` and `new` write nothing before their review gate.
- Do not modify `eod`, the session-start hook, or thread files from this skill.

## Gotchas

- `↻ N` needs the space when WRITTEN; readers (board, `detect-drift.ps1`) tolerate `↻N`.
- `links.tsv` is TAB-separated. PowerShell `-Encoding utf8` writes a BOM that corrupts parsing —
  edit with the Edit tool / UTF-8-no-BOM. See memory `powershell-bom-breaks-json`.
- Areas are keyed by the `id:` metadata line, NOT the heading text — headings may be reworded freely.
- `goals.md` is hand-editable by design; parsers must tolerate blank lines and `> note` lines
  between tasks.
- If `goals.md` ever outgrows eyeballing, splitting back to per-area files is a deliberate future
  change — update `detect-drift.ps1` + `modes/board.md` in lockstep (both parse this format).

## Versioning

- Trigger misfires (esp. vs `/log` / `/catchup` / `/eod` / `/today`) → tighten the router
  `description` first.
- Format changes here ripple to: `modes/board.md`, `modes/today.md`, `modes/review.md`,
  `modes/manage.md`, `janitor/detect-drift.ps1`. Update them together.
