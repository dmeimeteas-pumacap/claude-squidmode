# Claude Kit -- Install / Update / Uninstall

v1 is **Windows-only** (the bootstrap uses PowerShell + Task Scheduler). The plugin half is
OS-agnostic; a `bootstrap.sh` for macOS/Linux is planned for v2.

> Want the skills without the bootstrap (on a Mac, on Linux, or in Claude.ai/desktop)? That
> path exists today -- see **LITE.md**. This file covers the full Windows install.

## Step 0: Install Claude Code (skip if the CLI is already set up)
If you only use Claude Code via the VS Code extension, the CLI itself may not be installed. This kit
installs into that CLI, so set it up first (Windows):

1. In **PowerShell**: `irm https://claude.ai/install.ps1 | iex`
   (or `winget install Anthropic.ClaudeCode`, or with Node.js 18+, `npm install -g @anthropic-ai/claude-code`).
2. Install **Git for Windows** (https://git-scm.com/downloads/win) -- required, the hooks run under Git Bash.
3. Run `claude` once and finish the browser login (Pro/Max/Team/Enterprise plan required).
4. **VS Code:** install the **Claude Code** extension from the Marketplace and reload; it uses the CLI
   from step 1. Running `claude` in the integrated terminal also works.
5. Verify with `claude --version` and `claude doctor`.

Reference: https://code.claude.com/docs/en/setup

## Prerequisites
- Claude Code (Step 0), PowerShell 5.1+, and **Git for Windows** installed. The installer pins the plugin hooks
  to Git Bash's absolute path, so PATH order no longer matters (it warns only if Git Bash isn't found).

## Install
```
claude plugin marketplace add <kit-repo-url>
claude plugin install dimitri-claude-kit
powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap\install.ps1
```
Then restart Claude Code.

**Installer flags:**
- `-InstallEodSchedule` -- opt in to the scheduled daily `/eod`. NOTE: this runs Claude ~twice a day
  against *your* usage allowance.
- `-IncludeStatusLine` -- adopt the kit statusline even if you already have one (backs yours up first).
- `-Interactive` -- prompt on each `settings.json` scalar conflict instead of keeping your value.
- `-SkipExternalPlugins` -- don't touch your plugin set (skip the optional-enhancement installs).

**What the installer does (merge-safe):** backs up anything it touches to `~/.claude/.kit-backups/<stamp>/`,
fills only missing `settings.json` keys (keeps your values on conflict + reports them), never touches an
existing `CLAUDE.md` (drops `CLAUDE.kit-template.md` beside it), skips an existing statusline unless you
opt in, creates only missing scaffold dirs, and writes an install receipt
(`~/.claude/.kit-install-receipt.json`). It also pins the plugin hooks to Git Bash's absolute path so
PATH order can't break them (a `claude plugin update` resets this, so re-run the installer afterward).
It prints a summary of everything it skipped or kept.

## Update
1. Plugin half: `claude plugin update`
2. Bootstrap half: re-run `install.ps1` (idempotent + merge-safe; a no-op run changes nothing).

The two halves carry a version stamp; if the session-start hook warns about a version mismatch, you
updated the plugin without re-running `install.ps1` -- just re-run it.

## Uninstall (v1: manual, receipt-driven)
An automated `Uninstall-ClaudeKit` is planned for v2. For now, removal is straightforward because the
install recorded everything:
1. `claude plugin uninstall dimitri-claude-kit` (+ `claude plugin marketplace remove ...` if desired).
2. **Restore overwritten files** from the newest `~/.claude/.kit-backups/<stamp>/` (settings.json,
   CLAUDE.md, statusline.ps1, themes/ -- whatever is present there).
3. **Reverse the additions** listed in `~/.claude/.kit-install-receipt.json`:
   - remove the `_kitVersion` key and any `settingsKeysAdded` from `settings.json`;
   - `schtasks /delete /tn ClaudeEOD-Afternoon` and `/tn ClaudeEOD-Evening` if you enabled the schedule;
   - delete any `scaffoldDirsCreated` that are still empty;
   - `claude plugin uninstall` any `pluginsInstalled` you don't want.
4. Your own `threads/`, `goals/`, `session-notes/` content was never touched -- leave or delete as you like.

The backup restores what was overwritten; the receipt reverses what was added. Together they make the
removal complete and version-independent.
