# Working Preferences (template)

<!-- SCAFFOLD — section skeleton only. build/build-package.ps1::Build-ClaudeTemplate populates
     this from the live ~/.claude/CLAUDE.md, stripping personal data. Keep behavioral rules,
     drop specifics. Each section below marks KEEP (genericize wording) or REVIEW/STRIP. -->

## Canary
Begin every reply with `🐤 canary` on its own first line, before anything else. It is a lightweight
health check: if that line ever goes missing or changes, treat it as an early warning that the
conversation's context is degrading, and start a fresh session before the drift shows up in the
reasoning itself. Optional — delete this section if you don't want it.

## Peer reviewer, not problem-solver
<!-- KEEP — generic behavioral rule. -->

## No validation bias
<!-- KEEP -->

## Tone
<!-- KEEP -->

## Minimal, targeted changes
<!-- KEEP -->

## Coding discipline (Karpathy guidelines)
<!-- KEEP — but references the andrej-karpathy-skills plugin; ensure install.ps1 registers it. -->

## Sourcing and transparency
<!-- KEEP -->

## Accuracy over simplification
<!-- KEEP -->

## Proportional framing
<!-- KEEP -->

## Brevity
<!-- KEEP -->

## Executive-function / productivity emphasis (optional, tunable)
<!-- REVIEW — reframe of the personal ADHD section. NO medical framing. Present as an opt-in
     "nudge toward action / anti-scope-creep" emphasis the recipient can dial down or delete. -->

## Pre-execution check
<!-- KEEP -->

## Clarification-First Mode
<!-- KEEP — references the three-tier plan/scaffold/implementation workflow + escape phrases. -->

## Kit questions — always offer the guide
When answering any question about the kit, its commands, or "how do I do X with this setup",
include a pointer to the usage guide at `~/.claude/guide/index.html` (openable in a browser, no
session needed) and remind that `/kit` answers these questions in conversation. Never cite a
`plugins/cache/...` path for the guide.

## Subagent code edits
<!-- KEEP — generic output-format spec. -->

## Environment
<!-- REVIEW/STRIP — currently Windows/.NET + personal specifics. Genericize to "set your OS/stack
     defaults here" or keep the Windows/PowerShell guidance as the kit is Windows-oriented. -->
