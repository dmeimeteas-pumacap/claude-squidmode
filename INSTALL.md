# Claude Kit -- Install / Update / Uninstall

v1 is **Windows-only** (the bootstrap uses PowerShell + Task Scheduler). The plugin half is
OS-agnostic; a `bootstrap.sh` for macOS/Linux is planned for v2.

## Prerequisites
- Claude Code, PowerShell 5.1+, and **Git for Windows** with Git Bash ahead of the WSL stub on PATH
  (the hooks invoke `bash`; the installer checks and warns if `bash` resolves to `System32\bash.exe`).

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

**What the installer does (merge-safe):** backs up anything it touches to `~/.claude/.kit-backups/<stamp>/`,
fills only missing `settings.json` keys (keeps your values on conflict + reports them), never touches an
existing `CLAUDE.md` (drops `CLAUDE.kit-template.md` beside it), skips an existing statusline unless you
opt in, creates only missing scaffold dirs, and writes an install receipt
(`~/.claude/.kit-install-receipt.json`). It prints a summary of everything it skipped or kept.

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
