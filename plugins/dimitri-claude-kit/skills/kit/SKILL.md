---
name: kit
description: "Explain what this Claude kit can do and which command fits what you're trying to do. Answers from the shipped usage guide, at whatever depth is asked for. Use when the user says '/kit', asks what the kit or its commands can do, asks which command to use for something, describes a goal in their own words and needs it routed to the right command ('I want to remember what I decided', 'how do I not lose my place'), asks what a specific kit command does or how it differs from a similar one, asks what the startup banner / statusline / drift message is, asks what files the kit created or where its data lives, or reports that something in the kit did not work. Also triggers on 'how do I get started with this', 'what commands are there', 'what does this thing actually do'. NOT for Claude Code's own features (that is the built-in /help), NOT for the hands-on first-run walkthrough (/tutorial), NOT for building a new skill (/skill-builder)."
user-invocable: true
disable-model-invocation: false
argument-hint: "[<command> | <layer> | <what you're trying to do>]"
---

# Kit Skill (the usage guide, answered in conversation)

The kit's own reference. `/tutorial` teaches the core loop hands-on once; this answers "what is here"
and "which one do I use" any time after that, at full depth on request.

**The content lives in HTML, and this skill reads it.** There is no second copy of the prose in this
skill, deliberately — a duplicated inventory is how the kit ended up with a dead `/help` reference and
a stale manifest claim in the first place. Read the pages under
`${CLAUDE_PLUGIN_ROOT}/guide/` (the installer also drops a stable human-openable copy at
`~/.claude/guide/`):

| Page | Holds |
|---|---|
| `index.html` | Overview, START HERE, the confused pairs |
| `memory.html` | `/log` `/catchup` `/catchupall` `/logall` |
| `day.html` | `/goals` `/today` `/eod` `/eow` |
| `thinking.html` | `/grill-me` `/scrutinize` `/change-review` |
| `documentation.html` | `/document-process` `/document-section` |
| `upkeep.html` | `/reconcile` `/deepclean` `/tutorial` `/skill-builder` `/theme` `/kit` |
| `ambient.html` | What runs without being invoked (banner, hooks, detector, statusline, scheduled tasks) |
| `stores.html` | What lives where on disk |
| `troubleshooting.html` | By symptom |

Read only the page(s) the question needs. Never read all nine.

## Resolution — ONE path, do not branch on input shape

Trying to classify the argument before answering it is the trap. It arrives as free text; read it and
resolve against the guide. Apply in order, and stop at the first that fits:

1. **A shipped command name or alias** (`log`, `/log`, "the log command") → that command's entry, in
   full. Include its **when NOT to** field; that field is the whole reason someone asked.
2. **A layer name** (`memory`, `day`, `thinking`, `documentation`, `upkeep`) → that layer's inventory
   plus one line per command, then offer to go deep on any one.
3. **A reference section** (`ambient`, `stores`, `troubleshooting`) → that page's content. These are
   **not** command layers, so do not manufacture a command inventory for them.
4. **An intent in the user's own words** → route to the command, and **name the near-misses with why
   each is wrong**. A bare answer teaches nothing; the contrast is what makes it stick.
5. **Bare `/kit`** → the layered inventory (all layers, one line per command) plus the path to the HTML
   guide for browsing by hand.

**Two live readings → answer BOTH.** Do not pick. The answer is prose, so covering both costs a
paragraph while guessing wrong costs the user a retry. Mandatory for words this kit uses in more than
one sense:

| Word | Readings that must both appear |
|---|---|
| `review` | `/change-review` (always-on edit format) · `/scrutinize` (adversarial critique) |
| `store` / `memory` | memory files (durable facts) · threads (narrative of an effort) |
| `plan` | `/goals plan` (day-planning coach) · a `plans/*.md` design document |
| `status` | `/goals` board (standing) · `/today` (this day) · `/reconcile status` (truing records) |
| `help` | Claude Code's built-in `/help` (the tool) · this skill (the kit) |

## Hard rules

- **Never name a command that is not installed.** Before answering, resolve against
  `${CLAUDE_PLUGIN_ROOT}/skills/` **and** `${CLAUDE_PLUGIN_ROOT}/commands/`. Both, always: `/theme`
  ships as a command file rather than a skill, so a `skills/`-only check reports it missing and you
  would wrongly tell the user it does not exist.
- **Full depth on request, never a firehose by default.** Someone naming one thing gets everything about
  that thing. Someone asking broadly gets the map, not every page.
- **Read-only.** This skill writes nothing — no thread, no memory, no config. Explaining `/log` is not
  running it.
- **Do not answer for Claude Code itself.** Questions about the tool's own features, keybindings, or
  settings belong to the built-in `/help`. Say so and point there. This skill covers the kit only.
- **Cite the human path when pointing at the guide**: `~/.claude/guide/index.html`. Never a
  `plugins/cache/...` path — it is version-keyed and changes every release, so it is useless to paste.
- **If the guide and the installed skills disagree, the installed skills win.** Say that the guide looks
  stale rather than repeating it.

## Distinguishing it from its neighbours

| If the user wants | Send them to |
|---|---|
| To be walked through the core loop hands-on, once | `/tutorial` |
| To know what exists / which command / how two differ | **here** |
| Claude Code's own features, not the kit's | built-in `/help` |
| To build or fix a skill | `/skill-builder` |
| To browse at their own pace with no session | the HTML guide |

## Guardrails

- The guide is the source of truth for content; this file is the source of truth for **routing**. If a
  command's description here contradicts its entry in the guide, fix the guide, not this file.
- When a question is answered by one paragraph of one page, answer with that paragraph. Do not pad it
  to look thorough.
- Never invent a form or flag. If the guide's Forms field does not list it, it does not exist.

## Versioning

- A new shipped command needs: its entry in the right guide page, a tutorial catalog row, and nothing
  here — resolution is generic by design.
- `Assert-GuideCoverage` in `build-package.ps1` hard-fails the build if an installed command has no
  guide entry, or if the guide names a command that is not installed. That check is what keeps this
  skill honest; do not weaken it.
- Named `kit`, not `help`, on purpose: `/help` is Claude Code's built-in and the baseline door into the
  tool. Shadowing it would make the kit actively worse for a confused recipient. Same reason to avoid
  `/guide`, `/usage`, `/docs` if this is ever renamed — generic words a CLI may claim later.
