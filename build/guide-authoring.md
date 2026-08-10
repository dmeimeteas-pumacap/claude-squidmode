# Guide authoring — how to keep `guide/` true to the kit

Author-side only. **Not shipped** (`$ShipDocs` does not include it), so it can talk about build
internals freely.

Read this when `Assert-GuideCurrency` fails, when adding a command, or when changing what an existing
command does. The guide is written by a model, so this file is the spec that model works from.

---

## Why this exists

`Assert-GuideCoverage` proves every command has an entry carrying every required field class, and
that no entry references a command that does not exist. It says **nothing** about whether the prose is
still true.

v0.1.10 shipped the entire PROPAGATE lane while `upkeep.html` still called `/reconcile` a two-lane
command and never mentioned `/reconcile this` anywhere. Coverage passed for the whole release. The
gap was found by a human asking "is the guide actually current?", which is not a mechanism.

So: **coverage is structural, currency is semantic.** `Assert-GuideCurrency` catches the second by
stamping a hash of each command's `description` frontmatter — the one field that is already a
user-facing summary of what the command does — and hard-failing when it moves.

---

## The rule

**A change to what a command DOES is not finished until its guide entry says so.** Same discipline as
run-before-handoff: shipped-but-undocumented is a half-done change, not a done one with a doc debt.

When `Assert-GuideCurrency` fails it names the commands. For each one: open the skill, open the entry,
re-read them against each other, fix what is stale, then re-run with `-AcceptGuideDrift`.

**Do not reflexively pass `-AcceptGuideDrift`.** It exists for the case where the description changed
but the user-facing behaviour genuinely did not (a trigger-phrase tweak, a reworded blurb). Using it to
silence the gate turns it back into the thing that already failed once.

---

## Structure contract (enforced by `Assert-GuideCoverage` — do not drift from it)

- One command = one `<article class="entry" id="<command-name>">`. The `id` must be the bare command
  name, no slash.
- One topic/concept = `<div class="entry" id="...">`. **`article` vs `div` is load-bearing**: the gate
  counts `<article class="entry"` and requires it to equal the installed command count. A topic block
  written as an `article` breaks the build.
- Every command entry carries all six field classes:
  `f-lede` `f-forms` `f-what` `f-when` `f-not` `f-know`.
- Every command MENTION anywhere is `<code>/name</code>`. The gate scans that exact shape in both
  directions, so a mention of a command that is not installed fails the build. Host built-ins are
  allowed via a short explicit list in the gate (`help`, `clear`, `config`, `hooks`, `plugins`,
  `resume`) — extend that list rather than working around it.
- The version/count line is written by the build (`<p class="vstamp">`). Never hand-edit it, and never
  hardcode a version or a command count anywhere else in the guide.
- `ambient.html` cites script filenames as `<code>name.ps1</code>`; the gate verifies each cited script
  actually exists in the staged package. Cite a script only if it ships.

## Page map

| Page | Holds |
|---|---|
| `index.html` | The overview. Layer sections + the START HERE panel. Each layer links to its detail page. |
| `memory.html` | `/log` `/logall` `/catchup` `/catchupall` |
| `day.html` | `/today` `/goals` `/eod` `/eow` |
| `thinking.html` | `/scrutinize` `/grill-me` `/tdd` `/systematic-debugging` |
| `documentation.html` | the `document-*` family |
| `upkeep.html` | `/reconcile` `/deepclean` `/kit` `/tutorial` `/skill-builder` `/theme` |
| `ambient.html` | everything that speaks without being invoked: banner, staleness note, `[message]` line, drift detector, statusline, scheduled tasks |
| `stores.html` | where data lives. **Durable stores only** — ephemeral transports (e.g. `.inbox/`) are deliberately absent; adding a row asserts a durability the thing does not have. |
| `troubleshooting.html` | symptom → cause → fix |

A new command goes on the page matching its layer, and gets a card on `index.html`.

## Design rules (already settled — follow, do not re-litigate)

- **Fill the width.** Multi-column blocks use flex with `flex:1 1 0`, never an `auto-fit` grid: auto-fit
  pooled slack on the right and bunched the columns left. This was a real regression once.
- **Layer identity must survive losing colour.** Print collapses every accent to black, so each layer
  carries a glyph (`◆` memory · `✦` day · `△` thinking · `■` docs · `●` upkeep) on the detail-page `h1`
  and, via CSS `::before`, on the matching index heading. Keep the two in sync.
- **The page body never scrolls sideways.** Wide content scrolls inside its own container
  (`table.paths` is `display:block; overflow-x:auto`). Check at 375px.
- **Both themes.** Light and dark are driven by `prefers-color-scheme`; do not hardcode colours outside
  the `:root` variable blocks.
- **Print:** entries must not split across a page break; sections start on a new page. Do not add a
  forced break between entries — `page-break-inside:avoid` per entry is the contract.
- **Never cite a `plugins/cache/...` path.** It is version-keyed and changes every release. The stable
  human path is `~/.claude/guide/index.html`, which the installer creates.

## Voice

Second person, present tense, plain. Say what the thing does and when to reach for it. Prefer the
concrete failure it prevents over abstract benefit. State limits plainly — the `[message]` entry says
outright that a message can be lost and that there is no delivery receipt, and that honesty is the
point, not a flaw to smooth over.

---

## Procedure

1. Run the build. If `Assert-GuideCurrency` fails, it lists the commands needing a re-read.
2. For each: read `skills/<name>/SKILL.md` (at minimum its `description` and its mode/section headings)
   and the matching guide entry side by side.
3. Update the entry: the `f-lede` one-liner, the `f-forms` `<dl>` of invocations, and whichever
   `f-what` / `f-when` / `f-not` / `f-know` blocks moved. Adding a **mode or lane** almost always means
   a new `<dt>`/`<dd>` pair AND a block explaining it — a form with no explanation is how a feature ends
   up technically documented and practically invisible.
4. If the change touches something that speaks on its own, update `ambient.html` too, and check that
   page's own "N things talk to you" summary still counts correctly.
5. Cross-link related entries with a plain `<a href="page.html#id">`.
6. Re-run with `-AcceptGuideDrift`. Confirm the report shows the accepted commands.
7. Skim the rendered page once at desktop width before shipping.

## Known limits of the gate

- It keys on the `description` field. A behaviour change that leaves the description untouched will
  **not** trip it. Treat it as a floor, not a guarantee.
- It cannot judge prose quality, only that a re-read was prompted.
- Topic blocks (`div.entry`) are unstamped, since they map to no command. `ambient.html` and
  `stores.html` need manual attention when the ambient layer changes.
