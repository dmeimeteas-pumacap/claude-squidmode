# Vetting checklist — kit v0.1.8

**Additive.** `vetting-checklist-v0.1.7.md` (20 checks, 4 parts) is NOT replaced. Run both in the same
sitting; 0.1.7 has never been vetted, so its bugs will surface here and must not be misattributed.

**Rollback, if the round goes badly.** Reinstall from the snapshot at
`~/.claude/backups/kit-0.1.7-artifact/` — a `git archive` of `abaa3d7`. Do **not** try
`git checkout abaa3d7` + rebuild: `build-package.ps1` derives skills from live `~/.claude`, so a
rebuild carries whatever 0.1.8 edits are already there. `install.ps1` is additive and merge-safe, so it
is not a downgrade tool; uninstall the plugin first, then reinstall.

---

## PART 0 — SANDBOX-BLOCKED (run these first; they gate later work)

These cannot be verified from the author account. Everything below Part 0 assumes they passed.

### S1 — `/kit` is not shadowed by a built-in ⚠ GATES THE SKILL'S NAME

The whole reason the skill is not called `/help`: `/help` is a Claude Code built-in, and beyond that it
is the baseline door into the tool itself — a kit that eats it makes things worse for a confused
recipient. `/kit` is believed free but **unverified**.

Test it in the configuration that actually ships, which is plugin-namespaced, **not**
`~/.claude/skills/`:

```powershell
# as claudesbx, after installing the kit
$p = Get-ChildItem "$env:USERPROFILE\.claude\plugins\cache" -Recurse -Filter "dimitri-claude-kit" -Directory |
     Select-Object -First 1
Get-ChildItem $p.FullName        # confirm skills\ and the version leaf
# then, in a FRESH session:  /kit
```

- [ ] `/kit` resolves to the kit's skill, not a built-in and not "unknown command".
- [ ] Typing `/help` still gets **Claude Code's own help**, unchanged. This is the point — we are not
      gating the baseline command.

**If `/kit` collides:** stop and rename before writing more content. Fallbacks, in order:
`/whatis`, `/usage`, `/kitguide`. The cost is a find-and-replace across `SKILL.md`, the tutorial
catalog row, the guide's `<code>` mentions, and four docs — the assertion (Part 2) will catch any
mention missed.

### S2 — the guide is reachable by a human with no Claude session

- [ ] `~/.claude/guide/index.html` exists after a fresh install and opens in a browser.
- [ ] Its path appears in `INSTALL.md`, `QUICKSTART.md`, `README.md`, and the tutorial's closing line —
      and the cited path is `~/.claude/guide/...`, **never** a `plugins/cache/...` path (version-keyed,
      changes every release, useless in a doc).
- [ ] The install receipt records it.

### S3 — the plugin-side copy survives a rebuild

- [ ] After two consecutive `build-package.ps1` runs, `plugins/dimitri-claude-kit/guide/` still has all
      its files. `Promote-Stage` does `Remove-Item -Recurse -Force` on the plugin dir, so this fails
      unless `Sync-Guide` stages the folder from `$RepoRoot` first.

---

## PART 1 — `/kit` behaviour (5 resolution paths)

Ask each and check the shape of the answer, not just that it answered.

- [ ] **1. Command name** — `/kit log` → the `/log` entry in full, including its "when NOT to".
- [ ] **2. Layer name** — `/kit memory` → the layer inventory plus one line per command.
- [ ] **3. Reference section** — `/kit stores` → that page's content, and **no** empty command
      inventory (these are not command layers).
- [ ] **4. Intent** — `/kit "I want to remember what I decided"` → routes to `/log`, and names the
      near-misses (`/today`, memory, `/eod`) with why each is wrong.
- [ ] **5. Ambiguous word** — `/kit review` → answers **both** readings (`/change-review` and
      `/scrutinize`) rather than picking one. Same for `/kit "store memory"`.
- [ ] Bare `/kit` → layered inventory + the human-facing guide path.
- [ ] Ask for something the kit does not have → says so plainly, invents no command.

---

## PART 2 — the coverage assertion

- [ ] Delete one `<article class="entry">` from a guide page → build **fails**, naming the command.
- [ ] Add `<code>/nonesuch</code>` to a guide page → build **fails**, naming the token.
- [ ] Restore both → build passes.
- [ ] Remove one required field class from inside an article → build fails. (If it passes, the check is
      scoped to the page rather than the article, and is vacuous.)
- [ ] `-AllowIncompleteDocs` downgrades a real failure to a `[REVIEW]` line instead of aborting.
- [ ] Stamped command count on the page footers equals the number of entries, and equals
      `$ShipSkills.Count + $ShipCommands.Count`.

---

## PART 3 — content correctness

**Test the claims, not the prose.** 0.1.7's checklist item 5 was written to confirm a false statement
about `/eod` and would have passed a defect. Every ambient claim below is a behavioural assertion.

- [ ] **Banner** — matches what the page says, including the blank-board case.
- [ ] **Staleness hook** — fires on a store change from another session; fires **once** per change-set,
      not repeatedly.
- [ ] **Drift detector** — runs on demand, writes only janitor artifacts, modifies no store.
- [ ] **Scheduled EOD** — the page says Claude never invokes `/eod` itself but a scheduler can. Verify
      both halves: ask Claude to "wrap up my day" (must not reach it), and confirm
      `setup-eod-schedule.ps1` installs working tasks.
- [ ] **Statusline** — segments are what the page claims.
- [ ] **`CLAUDE.md`** — a recipient's existing file is not overwritten.
- [ ] **Stores page** — every listed path exists, or is correctly marked created-on-first-use.
- [ ] **Troubleshooting** — each of the 7 symptoms reproduces, and each stated fix works.

---

## PART 4 — presentation

- [ ] No horizontal scrolling on any page at 1280px and at 375px.
- [ ] START HERE and the detail columns fill the row — no bunching left. (Regression: `auto-fit` grid
      pooled slack on the right; the fix is flex with `flex:1 1 0`.)
- [ ] Print preview on two pages: nav hidden, light colours forced, all detail expanded, no entry
      split across a page break, and each section starts on a new page. (The CSS deliberately does
      NOT force a break between entries — `page-break-inside:avoid` per entry is the contract.)
- [ ] Layer identity readable without colour (glyphs present) — check in print and in greyscale.
- [ ] Both themes, light and dark.
- [ ] Version + count stamp present in every page footer.

---

## Reporting

Number findings by the check above. Split into **blocks release promotion** and **polish for 0.1.9**,
since this round decides whether `wip` → `release` can proceed.

**Known-deferred, do not file as defects:** the migration runner · the client-facing update-log ·
generating the HTML from markdown · `/kit` reading anything at runtime beyond the guide files.
