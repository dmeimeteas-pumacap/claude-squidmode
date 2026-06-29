# Claude Kit -- Quickstart

A portable continuity + planning setup for Claude Code: persistent thread/goal tracking, a
session-start briefing, daily wrap-ups, planning helpers, and a usage statusline.

## Install in ~60 seconds (Windows)
Prerequisite: **Git for Windows** (the hooks run under Git Bash) + Claude Code.
```
claude plugin marketplace add <kit-repo-url>
claude plugin install dimitri-claude-kit
powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap\install.ps1
```
Restart Claude Code so the hooks + statusline load. Full options + update/uninstall: **INSTALL.md**.

The installer is **merge-safe**: it backs up anything it touches, never overwrites your existing
`CLAUDE.md`/`settings.json`/statusline, and prints a summary of what it skipped.

## What you just got
- **Continuity** -- `threads/` (efforts tracked across days) + `goals/` (longer-horizon aims).
- **The daily loop** -- a session-start briefing of where you left off; `/log` to capture state;
  `/catchup` to resume; `/eod` for a cross-project daily summary.
- **Planning helpers** -- `grill-me` (interrogate a plan while forming it), `scrutinize-plan`
  (independent adversarial critique of a finished plan).
- **Statusline** -- live usage + context meters; `/theme` to recolor.

## Cheat-sheet (the ones you'll use daily)
| Command | Does |
|---------|------|
| `/log` | Capture where you are on a thread (Did / Thinking / Next) |
| `/catchup` | Resume a thread -- briefs you on where you left off |
| `/catchupall` | Panoramic view of all active threads |
| `/eod` | Cross-project summary of today |
| `/goals plan` | Today's derived plan + next-action recommendation |
| `/goals review` | Keep/done/drop sweep over your goals |
| `grill-me` | "Grill me on this plan" -- one question at a time |
| `scrutinize-plan` | Independent adversarial critique of a plan/design |
| `/theme` | Switch the statusline palette / bar / base |

## Tips
- Your data lives in `~/.claude/threads`, `~/.claude/goals`, `~/.claude/session-notes` -- yours, never shipped.
- Update later with `claude plugin update` + re-run `install.ps1` (see INSTALL.md).
- Full per-feature reference: **GUIDE.md**.
