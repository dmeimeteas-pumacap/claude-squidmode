# Claude Kit -- Lite Mode (skills + info, no terminal setup)

For when you just want the skills and the working-style "info" without the full
Windows bootstrap (statusline, scheduled `/eod`, `settings.json` tuning, Task Scheduler).
Lite mode is **OS-agnostic** -- it works the same on macOS, Linux, and Windows.

Pick the flavor that matches where you run Claude:

| You run Claude in...                | Use flavor | What you get |
|-------------------------------------|------------|--------------|
| **Claude Code** (the CLI, any OS)   | **A**      | All 14 skills + `theme` command + both hooks. Skips only the statusline/settings/scheduled-eod polish. |
| **Claude.ai web or the desktop app** (no CLI) | **B** | The *portable* skills uploaded as Agent Skills + your preferences as Project instructions. Continuity/log/goals can't run here -- see the table. |

> Full Mac/Linux carryover (statusline + settings + scheduled `/eod` via a `bootstrap.sh`)
> is a planned v2 item. Lite mode is the no-bootstrap path that works *today*, everywhere.

---

## Flavor A -- Barebones Claude Code (any OS, plugin only)

The plugin half is OS-agnostic: its hooks invoke `bash` via `${CLAUDE_PLUGIN_ROOT}` and
resolve their data dir from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, so they run unmodified on
macOS/Linux. You just skip the PowerShell bootstrap.

```
claude plugin marketplace add <kit-repo-url>
claude plugin install dimitri-claude-kit
```

Restart Claude Code. That's it -- no `install.ps1`.

- **You get:** all 14 skills (`/log`, `/catchup`, `/goals`, `grill-me`, `scrutinize-plan`,
  the `document-*` set, `skill-builder`, ...), the `theme` command, and both hooks
  (session-start briefing + `expand`). The continuity skills create their `~/.claude/threads`
  and `~/.claude/goals` files on first use, so they work with no extra setup.
- **You skip (vs. the full Windows install):** the usage statusline, the `settings.json`
  model/theme/effort tuning, the genericized `CLAUDE.md` preferences, and the scheduled daily
  `/eod`. None of those are required for the skills to run -- they're polish.
- **Want the preferences too?** Copy `bootstrap/CLAUDE.template.md` into your own
  `~/.claude/CLAUDE.md` (it never overwrites an existing one). See "Carry the info" below.

Update later with `claude plugin update` (no installer to re-run in lite mode).

---

## Flavor B -- Plain Claude.ai / desktop app (no CLI)

Claude.ai and the desktop app support **Agent Skills** -- a skill is a folder with a
`SKILL.md` (YAML `name` + `description`, then markdown instructions), uploaded as a ZIP.
This is a different mechanism from Claude Code's filesystem skills, and **only the portable
skills carry over** (see the table). The continuity loop (`/log`, `/catchup`, `/goals`,
`/eod`) depends on local files + hooks and cannot run here.

**Prerequisites (one-time):** in Claude settings, enable **Code execution** under
*Settings > Capabilities*, then open *Customize > Skills*. Available on all plans
(skills are in beta for the API/Code-execution path).

**Steps:**
1. Pick the portable skills from the table below. Each lives at
   `plugins/dimitri-claude-kit/skills/<name>/` in this repo.
2. For each one, ZIP the skill folder **with the folder itself as the ZIP root** (not a
   parent wrapper). The folder's `SKILL.md` is the entry point.
3. In *Customize > Skills*, choose "Create a new skill" and upload the ZIP, or paste the
   `SKILL.md` body directly.
4. Verify with an example prompt (e.g. "grill me on this plan") so Claude invokes it.

> Filename casing: the kit ships `SKILL.md`. Some Claude.ai upload paths expect `skill.md`.
> If an upload is rejected, rename the file to lowercase and re-zip. Confirm against the
> in-app dialog -- I haven't pinned the exact casing rule.

---

## Portability table

What each shipped skill does in each flavor. "Partial" means it runs but loses something
structural; "No" means it depends on local files/hooks/PowerShell that don't exist there.

| Skill (or command) | Flavor A: barebones Claude Code | Flavor B: Claude.ai / desktop | Why |
|--------------------|:---:|:---:|-----|
| `grill-me`         | Yes | **Yes** | Pure conversational interrogation; no local state. |
| `change-review`    | Yes | **Yes** | Behavioral diff-output format; applies to any editing turn. |
| `scrutinize-plan`  | Yes | Partial | Spawns an *independent* subagent critic in Claude Code; on Claude.ai it degrades to an inline critique (loses the isolation). |
| `skill-builder`    | Yes | Partial | Builds *Claude Code* skills; usable as guidance, but the artifact targets the CLI. |
| `document-process` | Yes | Partial | Needs repo file access + writes a README; on Claude.ai works only over uploaded files and can't write back. |
| `document-section` | Yes | No | Orchestrates `document-process` across many projects and writes files -- no local FS to drive. |
| `/log` `/logall`   | Yes | No | Append to `~/.claude/threads/*`; no persistent local store the skill controls. |
| `/catchup` `/catchupall` | Yes | No | Read the thread/goal files written by `/log`. |
| `/goals`           | Yes | No | Reads/writes `~/.claude/goals/*` + links. |
| `/eod` `/eow`      | Yes | No | Synthesize local session/thread files into `session-notes/`. |
| `checkout`         | Yes | No | Local-workflow helper. |
| `theme` (command)  | Yes | No | Terminal statusline + PowerShell; no terminal in Claude.ai. |

The honest takeaway for Flavor B: you get the **planning/review behavior** (`grill-me`,
`scrutinize-plan`, `change-review`) and the **preferences**, not the continuity system.
The continuity system is the part that fundamentally needs Claude Code.

---

## Carry the info (everywhere)

The most portable, highest-value piece is the working-style "info" itself -- the behavioral
preferences. It travels independent of any skill:

- **Claude Code (any OS):** copy `bootstrap/CLAUDE.template.md` into `~/.claude/CLAUDE.md`
  (genericize the `Environment` section to your OS/stack first).
- **Claude.ai / desktop:** paste the same content into a **Project's custom instructions**
  (or your account-level custom instructions). That gives every chat in the project the
  peer-reviewer / minimal-edits / clarification-first behavior without any skill upload.

This is why lite mode is "skills + info": even where the skills can't run, the preferences do.

---

See **QUICKSTART.md** / **INSTALL.md** for the full Windows install, and **GUIDE.md** for the
per-feature reference.
