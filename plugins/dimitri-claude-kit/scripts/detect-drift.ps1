<#
.SYNOPSIS
  detect-drift.ps1 - continuity janitor detector (v1, REPORT-ONLY).
.DESCRIPTION
  Deterministic scan of the ~/.claude continuity stores (goals, threads, INDEX, links.tsv).
  Writes janitor/drift-latest.json (the single drift source consumed by the /goals board, the
  /reconcile skill, the staleness hook, and the session-start banner) + appends a one-line run
  record to janitor/drift-log.md.

  Contract: this script WRITES NOTHING to the stores. It only classifies drift and writes the
  two janitor artifacts. "AUTO-FIX class" findings are DETECTED and reported; fixes are applied
  in-session by the /reconcile skill via delegation to /log and /goals modes.

  General-cleanliness note: v1 covers the continuity stores. New cleanliness categories (promoted-
  draft cruft, orphaned plans, memory-index hygiene, etc.) are added later simply as new finding
  `kind`s in the same schema - no architectural change.

  PS 5.1 + BOM gotcha: this file is BOM-less, so PS 5.1 reads it as ANSI. Any non-ASCII glyph is
  built from a char code ([char]0x...), never written as a literal, or it would mojibake.
.PARAMETER ClaudeDir  the ~/.claude root; defaults to this script's parent dir.
.PARAMETER Quiet      suppress the console summary (still writes the artifacts).
#>
[CmdletBinding()]
param(
    # Default resolution: the script's parent dir when it actually is a .claude dir (the author
    # install runs from ~/.claude/janitor); otherwise ~/.claude (a plugin install runs this from
    # the plugin's scripts dir, whose parent is NOT the config dir). Callers may always override.
    [string]$ClaudeDir = $(
        $p = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { $null }
        if ($p -and ($p -like '*\.claude')) { $p } else { Join-Path $env:USERPROFILE '.claude' }
    ),
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# --- Reuse the BOM-safe writer from the accountability engine (single source). Capture our dir
#     BEFORE dot-sourcing (its param block resets $Base; the run body is dot-source-guarded). ---
$JanitorClaudeDir = $ClaudeDir
$acct = Join-Path $ClaudeDir 'accountability\accountability.ps1'
if (Test-Path $acct) { . $acct }
$ClaudeDir = $JanitorClaudeDir
if (-not (Get-Command Write-Utf8NoBom -ErrorAction SilentlyContinue)) {
    function Write-Utf8NoBom([string]$path, [string]$text) {
        [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
    }
}

$GoalsFile     = Join-Path $ClaudeDir 'goals\goals.md'   # the single-file area store (2026-07-31)
$ThreadsActive = Join-Path $ClaudeDir 'threads\active'
$ThreadsDone   = Join-Path $ClaudeDir 'threads\done'
$IndexPath     = Join-Path $ClaudeDir 'threads\INDEX.md'
$LinksPath     = Join-Path $ClaudeDir 'goals\links.tsv'
$JanitorDir    = Join-Path $ClaudeDir 'janitor'
$DriftJson     = Join-Path $JanitorDir 'drift-latest.json'
$DriftLog      = Join-Path $JanitorDir 'drift-log.md'
$ROLL          = [char]0x21BB   # the rollover glyph used on goal tasks
$ARROW         = [char]0x2192   # the cmd->pattern separator on live_progress lines

if (-not (Test-Path $JanitorDir)) { New-Item -ItemType Directory -Path $JanitorDir -Force | Out-Null }

$findings = New-Object System.Collections.Generic.List[object]
$liveResults = New-Object System.Collections.Generic.List[object]   # per-area live_progress counts, for the /goals board
function Add-Finding([string]$cls, [string]$kind, [string]$store, [string]$target, [string]$sev, [string]$detail, [string]$mode) {
    $findings.Add([pscustomobject]@{
        id = ("{0}:{1}" -f $kind, $target); class = $cls; kind = $kind; store = $store
        target = $target; severity = $sev; detail = $detail; suggested_mode = $mode })
}

# ---------- parsing helpers ----------
function Read-Lines([string]$p) { if (Test-Path $p) { return @(Get-Content $p -Encoding UTF8) } return @() }

function Get-FrontmatterEnd([string[]]$lines) {
    if ($lines.Count -lt 1 -or $lines[0] -notmatch '^---\s*$') { return -1 }
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^---\s*$') { return $i } }
    return -1
}

function Get-FmValue([string[]]$lines, [int]$fmEnd, [string]$key) {
    for ($i = 1; $i -lt $fmEnd; $i++) {
        if ($lines[$i] -match ("^{0}:\s*(.*)$" -f [regex]::Escape($key))) { return $Matches[1].Trim() }
    }
    return $null
}

function Get-Section([string[]]$lines, [string]$header) {
    # Return the lines under a "## <header>" section (until the next "## ").
    # TOLERANT heading match (0.1.10 finding R6-7): text prepended onto the heading LINE - e.g. an
    # "AUTO (AI-selected...)" marker written as a prefix rather than as the section's first line -
    # stops the line from STARTING with '##', which made the whole section invisible. The detector
    # then reported counts.total == 0 on a file that visibly carried both auto-capture traces:
    # flagged to a human, clean to the machinery, which is the worst failure direction available.
    # So match '##' anywhere on the line. The heading line itself is still excluded from the
    # returned buffer, because callers use the first buffered line as the section's opening prose.
    # The tolerance is NARROW on purpose. A first attempt matched '##' anywhere on the line, which
    # made any prose sentence containing an inline '## Next' act as a section boundary: the section
    # returned zero lines (reintroducing the very blindness this fixes) and produced a false
    # status_claims_done. Three active threads already carry such sentences. So: headings must start
    # the line, and the ONLY tolerated prefix is a known AUTO marker, stripped before the test.
    $cap = $false; $buf = @()
    foreach ($l in $lines) {
        $norm = if ($l -match 'AUTO \(AI-selected') { $l -replace '^.*?(?=##\s)', '' } else { $l }
        if ($norm -match '^\s*##\s') {
            if ($cap) { break }
            if ($norm -match ('^\s*##\s+' + [regex]::Escape($header))) { $cap = $true }
            continue
        }
        if ($cap) { $buf += $l }
    }
    return $buf
}

function Get-HeadingLine([string[]]$lines, [string]$header) {
    # The raw heading line for a section, so a marker living ON the heading is still seen (R6-7).
    # Same narrow rule as Get-Section: line-leading '##', or a known AUTO-marker prefix before it.
    return (@($lines | Where-Object {
        $n = if ($_ -match 'AUTO \(AI-selected') { $_ -replace '^.*?(?=##\s)', '' } else { $_ }
        $n -match ('^\s*##\s+' + [regex]::Escape($header))
    }) -join "`n")
}

function Get-FirstSentence([string]$text) {
    if (-not $text) { return '' }
    $m = [regex]::Match($text, '^(.*?[.!?])(\s|$)')
    if ($m.Success) { return $m.Groups[1].Value }
    return $text
}

function Get-FirstFraction([string]$text) {
    # First N/M-shaped count in the text, or $null.
    $m = [regex]::Match($text, '(\d+)\s*/\s*(\d+)')
    if ($m.Success) { return [pscustomobject]@{ num = [int]$m.Groups[1].Value; den = [int]$m.Groups[2].Value; raw = $m.Value } }
    return $null
}

function Parse-IndexRows([string[]]$lines) {
    # Map slug -> { section; lastCol; cell; multi } for every table row. Row identity is a cell that
    # is PURELY a wikilink (the Thread column). [[wikilinks]] embedded inside cell prose (e.g.
    # "...see [[other-slug]]") are NOT row identities and must be ignored, or every cross-reference
    # would read as a phantom row. A genuine merged row (a /log regen glitch joining two rows on one
    # physical line) shows up as >1 pure-wikilink cell on the line.
    $rows = @{}; $section = ''
    foreach ($l in $lines) {
        if ($l -match '^##\s+Active')         { $section = 'active'; continue }
        if ($l -match '^##\s+Paused')         { $section = 'paused'; continue }
        if ($l -match '^##\s+Recently done')  { $section = 'done';   continue }
        if ($l -notmatch '^\s*\|') { continue }   # table rows only
        $cells = ($l.Trim() -replace '^\|', '') -split '\|'
        $pure = @()
        foreach ($c in $cells) { if ($c.Trim() -match '^\[\[([^\]]+)\]\]$') { $pure += $Matches[1] } }
        if ($pure.Count -lt 1) { continue }       # header / separator / non-row lines
        $multi = ($pure.Count -gt 1)
        $lastCol = $null; $cell = $null
        if (-not $multi -and $cells.Count -ge 5) { $lastCol = $cells[3].Trim(); $cell = $cells[4].Trim() }
        foreach ($slug in $pure) {
            # Record every pure slug as present (so the 2nd half of a merged row isn't "missing"),
            # but only the clean single-row case carries lastCol/cell.
            $rows[$slug] = [pscustomobject]@{ section = $section; lastCol = $lastCol; cell = $cell; multi = $multi }
        }
    }
    return $rows
}

# ---------- load stores ----------
$indexLines = Read-Lines $IndexPath
$indexRows  = Parse-IndexRows $indexLines

$links = @()
foreach ($ln in (Read-Lines $LinksPath)) {
    if ($ln -match '^\s*$') { continue }
    $p = $ln -split "`t"
    if ($p.Count -ge 2) { $links += [pscustomobject]@{ goal = $p[0].Trim(); thread = $p[1].Trim(); role = ($(if ($p.Count -ge 3) { $p[2].Trim() } else { 'supporting' })) } }
}

# Thread index: slug -> { status; last_touched; wloFirstSentence; openNext; path; loc }
$threads = @{}
foreach ($loc in @(@{dir = $ThreadsActive; tag = 'active' }, @{dir = $ThreadsDone; tag = 'done' })) {
    if (-not (Test-Path $loc.dir)) { continue }
    foreach ($f in (Get-ChildItem -Path $loc.dir -Filter '*.md' -File)) {
        $lines = Read-Lines $f.FullName
        $fmEnd = Get-FrontmatterEnd $lines
        if ($fmEnd -lt 0) { continue }
        $status = Get-FmValue $lines $fmEnd 'status'
        $lt     = Get-FmValue $lines $fmEnd 'last_touched'
        $wloSec = @(Get-Section $lines 'Where I left off')
        $wlo    = ($wloSec | Where-Object { $_.Trim() } | Select-Object -First 1)
        $nextSec = Get-Section $lines 'Next'
        $openNext = @($nextSec | Where-Object { $_ -match '^\s*-\s*\[ \]' })
        # Auto-capture bookkeeping: the '/log auto' mode leaves TWO traces - a marker prefixing
        # 'Where I left off' and an open 'Confirm this auto-capture' item in ## Next. Either one
        # left behind means the human check never happened. Cleared only by '/log confirm' (3f).
        # Scan the WHOLE section, not just its first line: a later capture prepends a fresh
        # paragraph and demotes the prior one under 'Prior:', which pushes an AUTO marker out of
        # the first line while leaving it very much present.
        # Include the heading LINE in the marker scan (R6-7): a marker written as a prefix on
        # '## Where I left off' rather than as the section's first line is still a marker.
        $autoMarked   = ((($wloSec -join "`n") + "`n" + (Get-HeadingLine $lines 'Where I left off')) -match 'AUTO \(AI-selected')
        # Tolerate a confirm item whose '-' bullet is missing (same R6-7 fixture): a line that opens
        # with '[ ]' is an open checkbox by any reasonable reading. Scoped to THIS scan only -
        # openNextCount above stays strict so other findings' counts are not inflated.
        $confirmBoxes = @($nextSec | Where-Object { $_ -match '^\s*-?\s*\[ \]' -and $_ -match '(?i)confirm.{0,40}auto-capture' }).Count
        $threads[$f.BaseName] = [pscustomobject]@{
            status = $status; last_touched = $lt; wlo = ([string]$wlo)
            wloFirst = (Get-FirstSentence ([string]$wlo)); openNextCount = $openNext.Count
            autoMarked = $autoMarked; confirmBoxes = $confirmBoxes
            loc = $loc.tag; path = $f.FullName }
    }
}

# ---------- structural checks (AUTO-FIX class: detected + reported; writer deferred) ----------
# Expected INDEX table per thread location/status.
foreach ($slug in $threads.Keys) {
    $t = $threads[$slug]
    $expected = if ($t.loc -eq 'done' -or $t.status -eq 'done') { 'done' } elseif ($t.status -eq 'paused') { 'paused' } else { 'active' }
    $row = $indexRows[$slug]
    if ($null -eq $row) {
        # Only active/paused threads must have a live dashboard row; done threads roll off after 30d.
        if ($expected -ne 'done') {
            Add-Finding 'autofix' 'index_row_missing' 'index' $slug 'med' "active/paused thread has no INDEX row" 'log-capture'
        }
        continue
    }
    if ($row.section -ne $expected) {
        Add-Finding 'autofix' 'index_wrong_table' 'index' $slug 'med' ("thread is '{0}' but INDEX row sits under '{1}'" -f $expected, $row.section) 'log-capture'
    }
    if ($row.multi) {
        Add-Finding 'report' 'malformed_index_row' 'index' $slug 'low' "INDEX row line carries more than one [[slug]] (rows merged)" 'log-capture'
    }
    elseif ($expected -ne 'done' -and $t.last_touched -and $row.lastCol) {
        $expectMMDD = ''
        if ($t.last_touched -match '^\d{4}-(\d{2})-(\d{2})$') { $expectMMDD = "{0}-{1}" -f $Matches[1], $Matches[2] }
        if ($expectMMDD -and $row.lastCol -ne $expectMMDD) {
            Add-Finding 'autofix' 'index_stale_date' 'index' $slug 'low' ("INDEX Last={0} but thread last_touched={1}" -f $row.lastCol, $expectMMDD) 'log-capture'
        }
    }
}
# Orphan rows: INDEX lists a slug with no file in active/ or done/.
foreach ($slug in $indexRows.Keys) {
    if (-not $threads.ContainsKey($slug)) {
        Add-Finding 'autofix' 'index_row_orphan' 'index' $slug 'med' "INDEX row has no matching thread file" 'manual'
    }
}

# ---------- snapshot_trails_live (REPORT; the B1-corrected high-value check) ----------
# Map goal -> primary thread (fallback: any linked thread).
function Get-PrimaryThread([string]$goalId) {
    $prim = $links | Where-Object { $_.goal -eq $goalId -and $_.role -eq 'primary' } | Select-Object -First 1
    if ($prim) { return $prim.thread }
    $any = $links | Where-Object { $_.goal -eq $goalId } | Select-Object -First 1
    if ($any) { return $any.thread }
    return $null
}

# Parse the single-file area store: each "## " section = an area keyed by its "id:" metadata line.
# Tolerates blank lines and "> note" lines between tasks (hand-editable by design).
function Get-GoalAreas([string]$path) {
    $areas = @(); $cur = $null
    if (-not (Test-Path $path)) { return $areas }
    $lpRegex = '^live_progress:\s*`([^`]+)`\s*' + [regex]::Escape([string]$ARROW) + '\s*`(.+)`\s*$'
    foreach ($l in (Read-Lines $path)) {
        if ($l -match '^##\s+(.+)$') {
            if ($cur) { $areas += $cur }
            $cur = [pscustomobject]@{ title = $Matches[1].Trim(); id = $null; lp = $null; lines = @() }
            continue
        }
        if (-not $cur) { continue }   # the "# Goals" header + preamble blockquote
        $cur.lines += $l
        if (-not $cur.id -and $l -match '^id:\s*([A-Za-z0-9-]+)') { $cur.id = $Matches[1] }
        if (-not $cur.lp -and $l -match $lpRegex) {
            $cur.lp = [pscustomobject]@{ cmd = $Matches[1].Trim(); pattern = $Matches[2].Trim() }
        }
    }
    if ($cur) { $areas += $cur }
    return $areas
}

$goalAreas = Get-GoalAreas $GoalsFile
foreach ($area in $goalAreas) {
    if (-not $area.id) {
        Add-Finding 'report' 'goal_area_unkeyed' 'goal' $area.title 'low' "goals.md area section has no 'id:' metadata line - links/live reads cannot key it" 'manual'
        continue
    }
    $goalId = $area.id

        # over_rolled_goal: any task rolled >= 4 times.
        foreach ($l in $area.lines) {
            $m = [regex]::Match($l, ([regex]::Escape([string]$ROLL) + '\s*(\d+)'))
            if ($m.Success -and [int]$m.Groups[1].Value -ge 4) {
                Add-Finding 'report' 'over_rolled_goal' 'goal' $goalId 'med' ("a task has rolled {0}x ({1}) - re-scope or drop" -f $m.Groups[1].Value, $ROLL) 'goals-review'
                break
            }
        }

        $lp = $area.lp
        if (-not $lp) { continue }

        # Run the live command; failure or no-match => live_read_failed, never a false stale flag.
        $live = $null
        try {
            $out = (Invoke-Expression $lp.cmd 2>&1 | Out-String)
            if ($lp.pattern -and $out -match $lp.pattern) {
                $live = [pscustomobject]@{ num = [int]$Matches[1]; den = [int]$Matches[2] }
            }
        } catch { $live = $null }
        if (-not $live) {
            $liveResults.Add([pscustomobject]@{ goal = $goalId; ok = $false; num = $null; den = $null; pct = $null })
            Add-Finding 'report' 'live_read_failed' 'goal' $goalId 'low' "live_progress command failed or did not match its pattern" 'manual'
            continue
        }
        $pct = if ($live.den -gt 0) { [int][math]::Round(100.0 * $live.num / $live.den) } else { 0 }
        $liveResults.Add([pscustomobject]@{ goal = $goalId; ok = $true; num = $live.num; den = $live.den; pct = $pct })

        $thSlug = Get-PrimaryThread $goalId
        if (-not $thSlug -or -not $threads.ContainsKey($thSlug)) { continue }
        $th = $threads[$thSlug]

        # Compare against the rolling current-state pointers ONLY: the thread's where-left-off FIRST
        # sentence and its INDEX one-liner. Never goal horizon milestones / ## Log / historical prose.
        $snap = Get-FirstFraction $th.wloFirst
        if (-not $snap -and $indexRows.ContainsKey($thSlug) -and $indexRows[$thSlug].cell) {
            $snap = Get-FirstFraction $indexRows[$thSlug].cell
        }
        if (-not $snap) { continue }

        # Only flag when the snapshot is materially BEHIND live (the "trails" semantics). A snapshot
        # AHEAD of live is never a stale-snapshot signal - it means either the live source regressed
        # or its precondition is unmet (e.g. Audit.ps1 read on the wrong branch returning a low count,
        # the documented caveat). Flagging that would be a false positive, so suppress it.
        if ($snap.num -lt ($live.num - 1)) {
            $age = ''
            if ($th.last_touched -match '^\d{4}-\d{2}-\d{2}$') {
                try { $days = [Math]::Floor(((Get-Date).Date - ([datetime]$th.last_touched)).TotalDays); $age = "$days d" } catch { $age = $th.last_touched }
            }
            $sev = if ($age -and $age -ne '0 d') { 'med' } else { 'low' }
            Add-Finding 'report' 'snapshot_trails_live' 'thread' $thSlug $sev `
                ("snapshot {0}/{1} trails live {2}/{3} (goal {4}, last touched {5} ago)" -f $snap.num, $snap.den, $live.num, $live.den, $goalId, $age) `
                'log-capture'
        }
}

# ---------- status_claims_done (REPORT): an active thread with zero open ## Next items ----------
foreach ($slug in $threads.Keys) {
    $t = $threads[$slug]
    if ($t.loc -eq 'active' -and $t.status -eq 'active' -and $t.openNextCount -eq 0) {
        Add-Finding 'report' 'status_claims_done' 'thread' $slug 'low' "active thread has no open ## Next items - close it or add next steps" 'log-close'
    }
}

# ---------- auto_capture_unconfirmed (REPORT): '/log auto' captures never human-checked ----------
# An auto-capture asserts a MODEL's guess at which thread the work belonged to. Until a human
# confirms it, the thread's narrative may be filed under the wrong effort - so these accumulate as
# unverified state, not merely untidy checkboxes. Cleared by '/log confirm' (3f), never as a side
# effect of an unrelated capture. Age is measured off last_touched, the only date the frontmatter
# carries; a marker on a thread untouched for weeks is staler than the count alone suggests.
$AUTO_STALE_DAYS = 7
foreach ($slug in $threads.Keys) {
    $t = $threads[$slug]
    if ($t.loc -ne 'active') { continue }
    if (-not $t.autoMarked -and $t.confirmBoxes -eq 0) { continue }

    $ageDays = $null
    if ($t.last_touched -match '^\d{4}-\d{2}-\d{2}$') {
        # Floor, not [int]: [int] ROUNDS in PowerShell, so a thread touched today at 13:45 reported
        # "1 d ago" and the $AUTO_STALE_DAYS=7 escalation fired at 6.5 days (0.1.10 finding R5-7).
        try { $ageDays = [Math]::Floor(((Get-Date) - [datetime]::ParseExact($t.last_touched, 'yyyy-MM-dd', $null)).TotalDays) } catch { $ageDays = $null }
    }

    # Both traces present is the normal unconfirmed case. Exactly one present means a partial
    # clear - worth flagging distinctly, because it usually indicates a marker stripped by hand
    # or a confirm box ticked without running '/log confirm'.
    $detail = if ($t.autoMarked -and $t.confirmBoxes -gt 0) {
        "unconfirmed auto-capture: AUTO marker + {0} open confirm item(s)" -f $t.confirmBoxes
    } elseif ($t.autoMarked) {
        "AUTO marker present but NO open confirm item - partial clear, the human check is unrecorded"
    } else {
        "{0} open confirm item(s) but no AUTO marker - partial clear, marker likely stripped by hand" -f $t.confirmBoxes
    }
    if ($null -ne $ageDays) { $detail += (" (last touched {0} d ago)" -f $ageDays) }

    $sev = if ($null -ne $ageDays -and $ageDays -ge $AUTO_STALE_DAYS) { 'med' } else { 'low' }
    Add-Finding 'report' 'auto_capture_unconfirmed' 'thread' $slug $sev $detail 'log-confirm'
}

# ---------- links.tsv orphan rows (REPORT): a link edge whose goal or thread file is gone ----------
$goalIds = @{}
foreach ($area in $goalAreas) { if ($area.id) { $goalIds[$area.id] = $true } }
$goalsDone = Join-Path $ClaudeDir 'goals\done'
if (Test-Path $goalsDone) { foreach ($gf in (Get-ChildItem -Path $goalsDone -Filter '*.md' -File)) { $goalIds[$gf.BaseName] = $true } }
foreach ($lk in $links) {
    if ($lk.goal -and -not $goalIds.ContainsKey($lk.goal)) {
        Add-Finding 'report' 'links_goal_orphan' 'links' $lk.goal 'low' ("links.tsv edge references goal '{0}' with no goal file" -f $lk.goal) 'manual'
    }
    if ($lk.thread -and -not $threads.ContainsKey($lk.thread)) {
        Add-Finding 'report' 'links_thread_orphan' 'links' $lk.thread 'low' ("links.tsv edge references thread '{0}' with no thread file" -f $lk.thread) 'manual'
    }
}

# ---------- memory index hygiene (REPORT): MEMORY.md pointer <-> file, both directions ----------
$projRoot = Join-Path $ClaudeDir 'projects'
if (Test-Path $projRoot) {
    foreach ($scope in (Get-ChildItem -Path $projRoot -Directory)) {
        $memDir = Join-Path $scope.FullName 'memory'
        if (-not (Test-Path $memDir)) { continue }
        $indexPath = Join-Path $memDir 'MEMORY.md'
        $indexText = if (Test-Path $indexPath) { Get-Content $indexPath -Raw -Encoding UTF8 } else { '' }
        $files = @(Get-ChildItem -Path $memDir -Filter '*.md' -File | Where-Object { $_.Name -ne 'MEMORY.md' })
        # markdown link targets ending in .md -> pointed-to filenames
        $pointed = @{}
        foreach ($m in [regex]::Matches($indexText, '\(([^)]+\.md)\)')) {
            $pointed[[System.IO.Path]::GetFileName($m.Groups[1].Value)] = $true
        }
        foreach ($f in $files) {
            if (-not $pointed.ContainsKey($f.Name)) {
                Add-Finding 'report' 'memory_index_drift' 'memory' ("{0}/{1}" -f $scope.Name, $f.Name) 'low' 'memory file has no MEMORY.md pointer' 'manual'
            }
        }
        foreach ($p in $pointed.Keys) {
            if (-not (Test-Path (Join-Path $memDir $p))) {
                Add-Finding 'report' 'memory_index_drift' 'memory' ("{0}/{1}" -f $scope.Name, $p) 'low' 'MEMORY.md points to a file that does not exist' 'manual'
            }
        }
    }
}

# ---------- emit artifacts ----------
$autofix = @($findings | Where-Object { $_.class -eq 'autofix' }).Count
$report  = @($findings | Where-Object { $_.class -eq 'report' }).Count
$generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

$counts = [ordered]@{ autofix = $autofix; report = $report; total = $findings.Count }
$payload = [ordered]@{ generated = $generated; counts = $counts; live = $liveResults.ToArray(); findings = $findings.ToArray() }
Write-Utf8NoBom $DriftJson (($payload | ConvertTo-Json -Depth 6))

$logHead = if (Test-Path $DriftLog) { Get-Content $DriftLog -Raw -Encoding UTF8 } else { "# Janitor drift log`n`n" }
Write-Utf8NoBom $DriftLog ($logHead + ("- {0}  autofix={1} report={2} total={3}`n" -f $generated, $autofix, $report, $findings.Count))

if (-not $Quiet) {
    Write-Host ("janitor: {0} findings (autofix {1}, report {2}) -> {3}" -f $findings.Count, $autofix, $report, $DriftJson)
    foreach ($f in $findings) { Write-Host ("  [{0}] {1} {2} - {3}" -f $f.class, $f.kind, $f.target, $f.detail) }
}

# Exit 0 on success regardless of any live_progress sub-command's exit code (Invoke-Expression of a
# failing cmd leaves $LASTEXITCODE non-zero, which would otherwise mislead callers like the
# staleness hook and /reconcile).
exit 0
