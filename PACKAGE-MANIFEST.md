# Package manifest -- ALLOWLIST (what ships; nothing else does)

Source of truth for `build/build-package.ps1`. **Allowlist model (post-critique B3):** the build copies
ONLY files enumerated here. `Assert-NoPersonalData` is defense-in-depth on top and HARD-FAILS the build
on any hit. The executable allowlist lives in `build/build-package.ps1` (`$Allowlist`); this file is the
human-readable mirror -- keep them in sync.

## Plugin bucket (additive, namespaced, auto-discovered at plugin root)
- **Skills** (`skills/<name>/SKILL.md` + any sub-files): catchup, catchupall, change-review,
  deepclean, document-process, document-section, eod, eow, goals, grill-me, log, logall,
  reconcile, skill-builder, scrutinize, today, tutorial
  - since v0.1.6: `goals` + `today` are the two-door model (single-file `goals/goals.md` area store;
    `today` owns `accountability/today.md` directly — no CLI, external mirrors off by default via
    `accountability/config.json` `onenotePlanMirror:false`). `scrutinize` renamed from scrutinize-plan.
- **Commands** (`commands/*.md`): theme.md
- **Hooks** (`hooks/hooks.json` -> `scripts/`): session-start-global.sh, expand-prompt.sh,
  staleness-check.ps1 (UserPromptSubmit; the passive freshness layer since v0.1.6.1)
  - hook scripts are patched on sync to resolve `CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"` (D1).
- **Janitor engine** (`scripts/`): detect-drift.ps1 + staleness-check.ps1 (v0.1.6.1) — the shared
  drift detector reconcile/deepclean/board depend on; skills prefer `~/.claude/janitor/` and fall
  back to `${CLAUDE_PLUGIN_ROOT}/scripts/`; artifacts always write to `~/.claude/janitor/`.

## Bootstrap bucket (installed by `bootstrap/install.ps1`)
- statusline.ps1 + statusline-lib.ps1 (the bar dot-sources the lib; they ship together) + themes/cc-active.json
- settings.template.json (model, theme, effortLevel, autoUpdatesChannel; `_kitVersion` stamped at install)
- CLAUDE.template.md (genericized)
- scripts/setup-eod-schedule.ps1 + run-eod.ps1 (optional, Windows, opt-in)
- VERSION (KIT_VERSION string, written by build)

## Top-level docs
QUICKSTART.md, GUIDE.md, INSTALL.md, LITE.md, README.md (author-facing)

## EXCLUDED skills (deliberately NOT shipped in v1)
- maystreet-pull -- TheSquid/BLPAPI/MayStreet-specific
- test-safety-audit -- coupled to a TheSquid ledger path
- (reconcile + deepclean shipped in v0.1.6.1 with the janitor engine.
  update-statuses/current/task-tracker no longer exist -- folded 2026-07-31.)
- document-overall -- the system-overview skill is inherently tuned to YOUR system (hardcodes specific
  architecture/OneNote/DockerHub references); recipients build their own overview. Revisit if genericized.
- (morning is retired; not present)

## NEVER ship (personal / runtime state) -- enforced by Assert-NoPersonalData hard-fail
- `.credentials.json`, `.last-*`, `remote-settings.json`, `policy-limits.json`, `mcp-needs-auth-cache.json`
- `settings.local.json`, `settings.json` (live), `.kit-backups/`, `.kit-install-receipt.json`
- `daemon/`, `daemon.log`, `sessions/`, `projects/`, `history.jsonl`, `shell-snapshots/`, `jobs/`
- live content of `threads/` `session-notes/` `memory/` `goals/`
- `accountability/` (deferred subsystem), `plans/`, `drafts/`, `backups/`, `cache/`, `downloads/`,
  `paste-cache/`, `file-history/`, `stats-cache.json`, `.obsidian/`
- any file matching the personal-data scan (client names, tickers, absolute user paths) -- HARD FAIL.

## v0.1.8 additions

- `plugins/dimitri-claude-kit/skills/kit/` -- the `/kit` skill. Answers from the shipped guide;
  holds no copy of its prose. NOT named `help`: `/help` is Claude Code's own built-in and the
  baseline door into the tool, so the kit must not shadow it.
- `plugins/dimitri-claude-kit/guide/` -- 9 HTML pages + `style.css`. Authored REPO-SIDE (unlike
  skills, which derive from live `~/.claude`), staged by `Sync-Guide`, and copied to
  `~/.claude/guide/` by `install.ps1` so a human has a stable path. `Assert-GuideCoverage` in
  `build-package.ps1` hard-fails the build if an installed command has no guide entry or the guide
  names a command that does not ship.
