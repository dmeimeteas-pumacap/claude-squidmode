# dimitri-claude-kit

A portable export of a Claude Code continuity + productivity setup: thread-based logging
(`/log`, `/catchup`), daily orientation (`/morning`, `/eod`, `/goals`), documentation
generators, and `skill-builder`, plus the supporting statusline, hooks, and settings.

Windows-oriented (the bootstrap is PowerShell).

> **STATUS: SCAFFOLD.** Structure is in place; merge/scrub logic is stubbed. See *Open decisions*.

## Layout

```
claude-kit/
├── .claude-plugin/marketplace.json        marketplace listing (this repo IS the marketplace)
├── plugins/dimitri-claude-kit/            the plugin (additive, namespaced, safe to install)
│   ├── .claude-plugin/plugin.json
│   ├── hooks/hooks.json                   SessionStart + Stop
│   ├── skills/   commands/   scripts/     populated by build-package.ps1
├── bootstrap/                             plugin-uncarriable installs (recipient-side)
│   ├── install.ps1                        merge-safe, idempotent installer
│   ├── settings.template.json
│   └── CLAUDE.template.md
├── build/build-package.ps1                author-side rebuild (the "patch the export" loop)
└── PACKAGE-MANIFEST.md                    include / exclude buckets
```

## Two halves, two reasons

A Claude Code plugin **cannot** carry `statusLine`, user settings (`model`/`theme`/`effortLevel`),
`enabledPlugins`/`extraKnownMarketplaces`, OS scheduled tasks, or continuity files. So:

- **Plugin half** — skills/commands/hooks/agents. Additive and namespaced; installing it cannot
  clobber a recipient's existing config. Updated by `git pull` + `/plugin update`.
- **Bootstrap half** — everything above that a plugin can't carry. Writes files the recipient
  already owns, so it must be **merge-safe and idempotent** (the load-bearing problem).

## Install (recipient)

```powershell
# 1. add the marketplace + install the plugin
claude plugin marketplace add <this-repo-url>
claude  # then: /plugin install dimitri-claude-kit@dimitri-claude-kit

# 2. run the bootstrap for the uncarriable bits
pwsh ./bootstrap/install.ps1            # add -InstallEodSchedule for the daily /eod task
```

## Patch loop (author — you)

This is the "easy to patch as I update my setup" path:

```powershell
pwsh ./build/build-package.ps1          # re-derive plugin/ + bootstrap/ from live ~/.claude
git add -A && git commit -m "sync" && git push
```

Recipients then `git pull` + `/plugin update`. The build is idempotent — it regenerates the
shippable trees from your live `~/.claude` and runs a no-personal-data safety gate before commit.

## Open decisions (resolve before promoting out of drafts)

1. **Hook path resolution.** `session-start-global.sh` / `auto-wrap.sh` derive `CLAUDE_DIR` as
   `$(dirname BASH_SOURCE)/..`. Inside the plugin that points at the plugin root, not `~/.claude`
   where `threads/` and `session-notes/` live. Either patch the scripts on build to resolve
   `$HOME/.claude`, **or** ship the hooks via bootstrap into `~/.claude/hooks/` (reverting to the
   current working arrangement). Also: the Windows command uses bare `bash` — needs Git bash on PATH.
2. **settings.json merge strategy.** Fill-if-absent for scalars (model/theme/effort), prompt on
   conflict; statusLine overwrite only if absent; hooks dedupe-and-append. Confirm before wiring
   `Merge-SettingsJson`.
3. **External plugins.** Automate `claude plugin marketplace add` for karpathy-skills +
   code-simplifier, or just document the two commands?
4. **CLAUDE.md scrub.** Never overwrite an existing one — drop alongside as `CLAUDE.kit-template.md`.
   The ADHD-section reframe is human-judgement; emit a diff for review rather than auto-stripping.
5. **`auto-wrap.sh`** is not currently wired in live `settings.json`. Ship it (and wire it) or not?
6. **Coupled skills.** `maystreet-pull` (exclude) and `test-safety-audit` (exclude or genericize).
```
