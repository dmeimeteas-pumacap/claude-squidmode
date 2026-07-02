# Claude Kit -- Quickstart

A portable continuity + planning setup for Claude Code: persistent thread/goal tracking, a
session-start briefing, daily wrap-ups, planning helpers, and a usage statusline.

> **Fastest way to learn it: run `/tutorial`.** Once installed and restarted (below), `/tutorial`
> gives you an interactive, hands-on walkthrough — including how to bring over an existing Claude
> setup. Reading is optional; the tutorial does it with you.
>
> **Why do replies start with `🐤 canary`?** It's an optional health check from your `CLAUDE.md`: if
> that line ever disappears or changes, it's an early sign Claude's context is drifting and you
> should start a fresh session. Delete the Canary section in `CLAUDE.md` to turn it off.

> **Just want the skills, no terminal setup?** On macOS/Linux, or in Claude.ai/desktop, see
> **LITE.md** for the OS-agnostic skills-only path (no PowerShell bootstrap).

## Step 0: Install Claude Code (skip if you already have the CLI)
This kit installs *into* the Claude Code CLI. If you only use Claude Code through the VS Code
extension, the CLI may not be set up yet -- here's the one-time setup (Windows):

1. **Install the CLI.** In **PowerShell** (not CMD), run the native installer:
   ```
   irm https://claude.ai/install.ps1 | iex
   ```
   (Alternatives: `winget install Anthropic.ClaudeCode`, or with Node.js 18+, `npm install -g @anthropic-ai/claude-code`.)
2. **Install Git for Windows** if you don't have it: https://git-scm.com/downloads/win -- the kit's
   hooks run under Git Bash, so this is required, not optional.
3. **Sign in.** Run `claude` once and complete the browser login (needs a Pro/Max/Team/Enterprise
   plan; the free plan does not include Claude Code).
4. **VS Code users:** install the **Claude Code** extension from the Marketplace, then reload. The
   extension uses the CLI you just installed. You can also just run `claude` in the VS Code
   integrated terminal.
5. **Verify:** `claude --version` and `claude doctor` should both succeed.

Then continue below. Full platform/version details: https://code.claude.com/docs/en/setup

## Install in ~60 seconds (Windows)
Prerequisite: **Git for Windows** (the hooks run under Git Bash) + Claude Code (see Step 0).
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
