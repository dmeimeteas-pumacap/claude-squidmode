# Vetting checklist — kit v0.1.7

**Scope of this bump.** Cross-conversation synchronization (the live-session sweep) plus the tutorial
catch-up pass. HELP MODE and the HTML cheatsheet are deliberately NOT in this version; they moved to
0.1.8. Do not test for them.

**What shipped**

| Area | Change |
|---|---|
| `/reconcile` | New `unswept_live_session` judgment class, swept FIRST in Step 2; Step-4 handling; auto-persist guardrail; Step-5 unswept reporting; passive-layer blind spot documented |
| `/catchup` | New freshness-sweep section before briefing; briefing must state swept/unswept; guardrail clarifying sweep is a read and the follow-up is a `/log` delegation |
| `/tutorial` | Catalog gains `/today`, `/reconcile`, `/deepclean`; `/goals` one-liner corrected post-split; `/change-review` relabelled always-on; `/eod`//`/eow` user-typed-only clause; inverse catalog rule; dead `/help` reference removed; PACKAGE-MANIFEST no longer cited as a runtime check |
| `/today` (goals mode) | Sub-items are now LETTERED under their parent (`a.`, `b.`) instead of consuming top-level numbers; sidecar + tick verbs updated to match |

Two of those were found while building, not planned: the **dead `/help` reference** (the tutorial
told users `/help` lists everything, and no such command ships) and the **PACKAGE-MANIFEST citation**
(it lives above the plugin root, so recipients never receive it, making the rule unverifiable at
runtime). Both are instances of the same blind spot the inverse catalog rule now closes.

---

## Preconditions

1. **Rebuild the share with purge.** Repo deletions do not propagate otherwise — this was the root
   cause of round-2's phantom defect 14.
   ```powershell
   # from the dmeimeteas account
   & "$env:USERPROFILE\claude-sandbox-kit\rebuild.ps1"
   ```
   Confirm the output reports a `/PURGE` on the share and `/MIR` on the cache.

2. **Verify the version actually landed in the sandbox's installed plugin cache**, not just the repo.
   Every round so far has had at least one "fixed in repo, stale in cache" moment.
   ```powershell
   Get-Content "C:\claude-kit-share\plugins\dimitri-claude-kit\scripts\.kit-version"
   # expect: 0.1.7
   ```

3. **Restart Claude Code in the sandbox** after the rebuild. Skill and hook changes are not picked up
   mid-session.

4. **Seed state to sweep against.** Several checks below need at least one thread and at least one
   *other* session that touched the same topic. If the sandbox board is empty, run check 1 first and
   let it create the thread, then open a second sandbox conversation, talk about that same topic
   without logging, and leave it open. That second conversation IS the test fixture for checks 5-8.

---

## Part 1 — Tutorial catch-up (7 checks)

**1. Catalog completeness, forward direction.** Run `/tutorial` and go to Beat 3.
- [ ] Every command it names resolves to something real. Specifically it should NOT say `/help`.
- [ ] `/today`, `/reconcile`, `/deepclean` are now among the named skills.

**2. Catalog completeness, inverse direction.** Ask in the sandbox: *"compare the tutorial's skill
catalog against what's actually installed and tell me about any mismatch in either direction."*
- [ ] It checks BOTH `skills/` and `commands/` (a `skills/`-only check falsely flags `/theme`).
- [ ] It reports no mismatch. 17 skills ship; the catalog lists 16 of them plus `/theme`; `tutorial`
      is deliberately self-excluded.

**3. Post-split `/goals` wording.** In Beat 3, listen to how `/goals` is described.
- [ ] It describes standing areas and the status board, NOT "plan your day". The day door is `/today`.

**4. `/change-review` framing.**
- [ ] Presented as an always-on format with nothing to run, not as a command to try. If Beat 4's
      "keep learning" menu offers to walk you through `/change-review` hands-on, that is a fail.

**5. `/eod` and `/eow` invisibility.**
- [ ] The tutorial states once that these only run when the user types them.
- [ ] Cross-check the claim: ask the sandbox Claude to "wrap up my day and synthesize it". It must NOT
      successfully invoke `/eod`. If it does, the clause is wrong and needs removing, not keeping.

**6. Frontmatter routing.** Ask: *"what should I use to plan my day?"*
- [ ] Routes to `/today`. Nothing should route day-planning to `/goals` any more.

**7. PACKAGE-MANIFEST.** Ask: *"how do you know which skills the kit ships?"*
- [ ] Answers from the installed directories, not from PACKAGE-MANIFEST.md. If it claims to read a
      manifest file, that file is not on the recipient's disk and the answer is fabricated.

---

## Part 2 — Cross-conversation sync (the core of this bump, 6 checks)

These are the ones that matter. The failure mode being fixed is a confidently stale answer, which is
worse than an error, so read the reasoning and not just the conclusion.

**8. `/catchup` sweeps.** With the unlogged second conversation open (precondition 4), run
`/catchup <that-thread>` in a third conversation.
- [ ] It lists session JSONLs newer than the thread's `last_touched` rather than briefing straight off
      `## Where I left off`.
- [ ] The briefing explicitly says either "swept, nothing newer" or names the sessions it did not read.
- [ ] It does NOT silently present the thread's stale state as current.

**9. `/catchup` hands off instead of absorbing.** Same run.
- [ ] On finding the unlogged work it offers/delegates to `/log`. It should not write the capture
      itself (that would break the one-write rule), and it should not merely mention the gap and move on.

**10. Cheap-case restraint.** Run `/catchup` on a thread you logged to two minutes ago.
- [ ] No full sweep. The skill says to scale it to the ask; a day-to-day pickup on a fresh thread
      should not grind through every session file. If it sweeps exhaustively here, the escalation rule
      is too aggressive and wants tightening.

**11. `/reconcile sync` sweeps first.** Run `/reconcile sync`.
- [ ] The live-session sweep happens BEFORE the other judgment classes, not after the drift report.
- [ ] A `counts.total == 0` report does not end the run. It must still sweep, and must not say "stores
      are clean" on the strength of the detector alone.
- [ ] Sessions already in `threads/.logall-processed.tsv` are excluded as candidates.

**12. Auto-persist, unprompted.** Same run, with real unlogged work present.
- [ ] It routes the finding into `/log` in the same run without being asked to.
- [ ] It confirms WHICH thread, not WHETHER to capture. Being asked "want me to log this?" is a fail —
      that is the exact behaviour the guardrail exists to stop.
- [ ] With several sessions hitting one thread, it prefers `/logall`.

**13. Honest partial results.** Deliberately give it more candidates than it will read (talk about one
thread's topic across three separate unlogged conversations), then run `/reconcile sync`.
- [ ] Step 5 names the unswept session UUIDs and why.
- [ ] It does not report the stores as clean while candidates remain unread.

---

## Part 3 — `/today` sub-item lettering (3 checks)

This rode along from live `~/.claude` rather than being planned into the bump, so it is untested.

**14. Rendering.** Run `/today` and build a plan with at least one parent that has two children.
- [ ] Children render as bare `a.`, `b.` — not `1a`, not `3a`.
- [ ] Lettering restarts at `a` under each parent.
- [ ] Sub-items do not consume top-level numbers (a parent at 3 with two children is followed by
      top-level 4, not 5).

**15. Ticking by id.** Say "done 3, b".
- [ ] The right child flips, and only that one.

**16. Sidecar + re-render.** Add a new sub-item under an existing parent, then add a new top-level item.
- [ ] Adding the sub-item re-letters only that parent's children.
- [ ] Adding the top-level item renumbers the top level below it and the list is re-rendered so you
      are ticking against current ids.
- [ ] `accountability\today-goalmap.tsv` rows use the new id form.

---

## Part 4 — Regression spot-checks (4 checks)

Cheap, and these are the surfaces the last two rounds broke.

**17. Session-start banner** renders with the drift line, no hook error.
**18. Staleness hook** fires once when a store file changes mid-session, and not repeatedly.
**19. `/reconcile status` lane** still asks the user to type `/eod` and degrades honestly when absent.
**20. `/deepclean`** still finds its engine on a plugin install (the 0.1.6.2 plugin-root fallback).

- [ ] 17
- [ ] 18
- [ ] 19
- [ ] 20

---

## Reporting

Write findings to a report file on the sandbox desktop as in prior rounds, numbered by the check
above, each with: what you ran, what you expected, what happened. Split fixes into "blocks the
release promotion" and "polish for 0.1.8", since the whole point of this round is deciding whether
`wip` → `release` can proceed.

**Known-deferred, do not file as defects:** HELP MODE, the HTML cheatsheet, the migration runner, and
the client-facing update-log. All four are scoped after this round.
