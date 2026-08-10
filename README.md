# dimitri-claude-kit

A portable export of a Claude Code continuity + productivity setup: thread-based logging
(`/log`, `/catchup`, `/catchupall`), daily orientation (`/eod`, `/eow`, `/goals`), planning
helpers (`grill-me`, `scrutinize-plan`), documentation generators, and `skill-builder`, plus the
supporting statusline, hooks, and settings.

Windows-oriented (the bootstrap is PowerShell + Task Scheduler). The plugin half is OS-agnostic; a
`bootstrap.sh` for macOS/Linux is planned for v2.

> **STATUS: shipped (v0.1.3).** Merge-safe installer proven by a fixture test (15/15); an
> allowlist hard-fail leak guard runs on every build. New here? Start with **QUICKSTART.md**.
> Just want the skills without the terminal setup (incl. macOS/Claude.ai)? See **LITE.md**.

## Layout

```
.
├── .claude-plugin/marketplace.json        marketplace listing (this repo IS the marketplace)
├── plugins/dimitri-claude-kit/            the plugin (additive, namespaced, safe to install)
│   ├── .claude-plugin/plugin.json
│   ├── hooks/hooks.json                   SessionStart (briefing) + UserPromptSubmit (expand)
│   ├── skills/  commands/  scripts/       14 skills + theme command, synced by build-package.ps1
├── bootstrap/                             plugin-uncarriable installs (recipient-side)
│   ├── install.ps1                        merge-safe, idempotent installer
│   ├── settings.template.json
│   ├── CLAUDE.template.md
│   ├── statusline.ps1   themes/   scripts/
├── build/
│   ├── build-package.ps1                  author-side rebuild (the "patch the export" loop)
│   └── test-merge-safety.ps1              B1 no-clobber + idempotency fixture test
├── VERSION                                single source of truth for the version
├── QUICKSTART.md  GUIDE.md  INSTALL.md  LITE.md   user docs (+ GUIDE-skills.generated.md)
└── PACKAGE-MANIFEST.md                    the ship/never-ship allowlist
```

## Two halves, two reasons

A Claude Code plugin **cannot** carry `statusLine`, user settings (`model`/`theme`/`effortLevel`),
`enabledPlugins`/`extraKnownMarketplaces`, OS scheduled tasks, or continuity files. So:

- **Plugin half** — skills/commands/hooks/agents. Additive and namespaced; installing it cannot
  clobber a recipient's existing config. Updated by `claude plugin update`.
- **Bootstrap half** — everything above that a plugin can't carry. Writes files the recipient
  already owns, so it is **merge-safe and idempotent**: backs up anything it touches, fills only
  missing `settings.json` keys (keeps your value on conflict), never overwrites an existing
  `CLAUDE.md` or statusline, and writes an install receipt. This is the load-bearing problem, and
  it is covered by `build/test-merge-safety.ps1`.

## Install (recipient)

```
claude plugin marketplace add <this-repo-url>
claude plugin install dimitri-claude-kit
powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap\install.ps1
```

Then restart Claude Code. Prerequisite: **Git for Windows** (the hooks run under Git Bash; the
installer pins them to its absolute path, so PATH order doesn't matter). Full options +
update/uninstall are in **INSTALL.md**; the 60-second version is **QUICKSTART.md**.

**Skills only, no bootstrap (OS-agnostic):** to carry just the skills + preferences without the
Windows install -- on a Mac, on Linux, or into Claude.ai/desktop -- see **LITE.md**. It covers
plugin-only Claude Code (any OS) and the portable-subset path for plain Claude.ai.

## Patch loop (author)

The "easy to patch as I update my setup" path. The working branch is **`release`** (versionless,
the repo default); `main` is reserved for reviewed releases via PR.

```powershell
pwsh ./build/build-package.ps1          # re-derive plugin/ + bootstrap/ from live ~/.claude
# build runs a hard-fail no-personal-data gate before it finishes; it errors if anything leaks
git add -A && git commit -m "sync" && git push   # pushes to release (the default branch)
```

`build-package.ps1` reads the version from `VERSION` (bump that file to cut a new version),
regenerates the shippable trees from your live `~/.claude`, and runs the allowlist
`Assert-NoPersonalData` gate before completing. Recipients then `claude plugin update` + re-run
`install.ps1`.

## Design + decisions

The six original open decisions are all resolved (v1 locked 2026-06-29). Full design rationale,
the merge-safe invariant, and the resolved decisions live in the author's plan file referenced from
the build; per-feature behavior is documented in **GUIDE.md**.

## The usage guide (no Claude session needed)

After installing, open **`~/.claude/guide/index.html`** in a browser. It is the full reference for
every command the kit ships, plus what runs automatically, where files live, and how to fix common
problems. Nine pages, works offline, nothing to run.

In a conversation, `/kit` answers the same content interactively -- name a command, a topic, or just
what you are trying to do. (`/help` remains Claude Code's own; the kit does not take it over.)
