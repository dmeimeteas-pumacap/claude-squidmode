<#
.SYNOPSIS
  staleness-check.ps1 - UserPromptSubmit hook: mid-session staleness surfacing (read-only).
.DESCRIPTION
  Part of the passive freshness layer (see skills/reconcile/SKILL.md). Runs on every prompt
  submit, so it must stay fast: the store scan is a handful of LastWriteTime checks plus one
  small JSON read. The heavy lifting (running live_progress commands, drift classification)
  belongs to detect-drift.ps1 - never run it INLINE from here (the detached spawn below is the
  one sanctioned refresh path).

  Reports, at most once per change-set per session (stamped in janitor/staleness-seen.json):
    1. store files modified since this session last looked (another conversation moved state), and
    2. a drift-finding count that changed since last reported.
  Output = hook JSON with hookSpecificOutput.additionalContext; silence when nothing changed.

  Detector freshness: when drift-latest.json is older than ~10 minutes, this hook spawns ONE
  detached hidden detect-drift.ps1 run (fire-and-forget) so the next prompt sees fresh data.
  This replaced the ClaudeDriftDetect scheduled task (2026-07-31) - the detector now runs only
  while Claude is actually in use, never on an idle machine.

  BOM gotcha: this file is BOM-less, so PS 5.1 reads it as ANSI - keep it pure ASCII.
#>
[CmdletBinding()]
param([string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude'))

$ErrorActionPreference = 'SilentlyContinue'   # a hook must never block the prompt

# --- hook input (session_id) ---
$sessionId = 'unknown'
$promptText = ''
try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) {
        $o = $raw | ConvertFrom-Json
        if ($o.session_id) { $sessionId = [string]$o.session_id }
        if ($o.prompt) { $promptText = [string]$o.prompt }
    }
} catch {}

# --- inbox (PROPAGATE lane transport) constants ---
# TTL is deliberately short: a status update is only useful while both chats are still in play.
$INBOX_TTL_HOURS = 4
# Prompts a SIBLING UserPromptSubmit hook answers with {"decision":"block"}. On those turns the
# prompt is discarded, so anything emitted here is never seen -- deliver nothing and delete nothing,
# or the message dies unread. Keep in sync with hooks/expand-prompt.sh.
$INBOX_BLOCKING_PROMPTS = @('expand')

$janitorDir = Join-Path $ClaudeDir 'janitor'
if (-not (Test-Path $janitorDir)) { try { New-Item -ItemType Directory -Path $janitorDir -Force | Out-Null } catch {} }
$seenPath = Join-Path $janitorDir 'staleness-seen.json'
$now = Get-Date
$nowIso = $now.ToString('yyyy-MM-ddTHH:mm:ss')

# --- load per-session seen-state (trim entries older than 2 days) ---
$seen = @{}
try {
    if (Test-Path $seenPath) {
        $j = Get-Content $seenPath -Raw | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) {
            try { if (([datetime]$p.Value.touched) -gt $now.AddDays(-2)) { $seen[$p.Name] = $p.Value } } catch {}
        }
    }
} catch {}

$mine = $seen[$sessionId]
$firstCall = ($null -eq $mine)
if ($firstCall) {
    # Baseline = now. The SessionStart banner already covered state at open; this hook only
    # reports what changes AFTER the session is underway.
    $mine = [pscustomobject]@{ lastSeen = $nowIso; lastDrift = -1; lastDriftIds = $null; touched = $nowIso }
}
$lastSeen = [datetime]$mine.lastSeen

# --- 1. store files changed since lastSeen ---
$changed = @()
if (-not $firstCall) {
    $watch = @()
    $watch += Get-ChildItem (Join-Path $ClaudeDir 'threads\active\*.md') -File
    foreach ($p in @('threads\INDEX.md', 'goals\goals.md', 'goals\links.tsv',
                     'accountability\today.md', 'session-notes\eod-latest.md')) {
        $f = Get-Item (Join-Path $ClaudeDir $p); if ($f) { $watch += $f }
    }
    foreach ($f in $watch) {
        if ($f.LastWriteTime -gt $lastSeen) {
            $rel = $f.FullName.Substring($ClaudeDir.Length + 1)
            $changed += ('{0} ({1:HH:mm})' -f $rel, $f.LastWriteTime)
        }
    }
}

# --- 2. drift finding-SET changed since last reported. Keyed on the sorted finding IDs, not
#     the count: a change-set that swaps findings at the same count must still fire. And a
#     missing/unreadable report is NOT a clean report - leave the prior stamp untouched so the
#     first real report still gets announced. ---
$driftNote = $null
try {
    $djPath = Join-Path $ClaudeDir 'janitor\drift-latest.json'
    $dj = if (Test-Path $djPath) { Get-Content $djPath -Raw | ConvertFrom-Json } else { $null }
    if ($null -ne $dj -and $null -ne $dj.counts) {
        $total = [int]$dj.counts.total
        $ids = (@($dj.findings | ForEach-Object { [string]$_.id }) | Sort-Object) -join '|'
        if ($total -gt 0 -and $ids -ne [string]$mine.lastDriftIds) {
            $kinds = ($dj.findings | ForEach-Object { $_.kind } | Select-Object -Unique) -join ', '
            $driftNote = ('{0} drift finding(s) [{1}] as of {2}' -f $total, $kinds, $dj.generated)
        }
        $mine.lastDrift = $total
        $mine | Add-Member -NotePropertyName lastDriftIds -NotePropertyValue $ids -Force
    }
} catch {}

# --- persist seen-state (advance lastSeen only when we reported, so unnoticed changes re-fire) ---
if ($changed.Count -gt 0 -or $driftNote -or $firstCall) { $mine.lastSeen = $nowIso }
$mine.touched = $nowIso
$seen[$sessionId] = $mine
try {
    $out = New-Object psobject
    foreach ($k in $seen.Keys) { $out | Add-Member -NotePropertyName $k -NotePropertyValue $seen[$k] }
    [System.IO.File]::WriteAllText($seenPath, ($out | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
} catch {}

# --- detector freshness: spawn ONE detached refresh when the report is older than ~10 min ---
try {
    # The detector lives beside this script on a plugin install; at ~/.claude/janitor on the
    # author install. Prefer the config-dir copy, fall back to the sibling.
    $dd = Join-Path $ClaudeDir 'janitor\detect-drift.ps1'
    if (-not (Test-Path $dd) -and $PSScriptRoot) { $dd = Join-Path $PSScriptRoot 'detect-drift.ps1' }
    $dl = Get-Item (Join-Path $ClaudeDir 'janitor\drift-latest.json')
    $stale = (-not $dl) -or ($dl.LastWriteTime -lt $now.AddMinutes(-10))
    $lock = Join-Path $ClaudeDir 'janitor\detect-refresh.lock'
    $locked = (Test-Path $lock) -and ((Get-Item $lock).LastWriteTime -gt $now.AddMinutes(-5))
    if ($stale -and -not $locked -and (Test-Path $dd)) {
        [System.IO.File]::WriteAllText($lock, $nowIso, (New-Object System.Text.UTF8Encoding($false)))
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $dd),
            '-Quiet', '-ClaudeDir', ('"{0}"' -f $ClaudeDir))
    }
} catch {}

# --- inbox: messages sent to THIS conversation by /reconcile this (PROPAGATE lane) ---
# Transport, not a store: one JSON file per message, addressed by to_session, deleted on delivery,
# age-swept. Nothing here is durable and nothing accumulates.
$msgs = @()
try {
    $inboxDir = Join-Path $ClaudeDir '.inbox'
    if (Test-Path $inboxDir) {
        # 1. TTL sweep first, so an expired message can never be delivered. Non-recursive by design.
        $cutoff = $now.AddHours(-$INBOX_TTL_HOURS)
        foreach ($f in @(Get-ChildItem $inboxDir -Filter '*.json' -File)) {
            if ($f.LastWriteTime -lt $cutoff) { Remove-Item $f.FullName -Force }
        }
        # 2. Bail out entirely when a sibling hook will block this turn (see $INBOX_BLOCKING_PROMPTS).
        $bare = $promptText.Trim().ToLower()
        if ($INBOX_BLOCKING_PROMPTS -notcontains $bare) {
            # 3. Select MINE first, then cap at 3 per turn. Order matters: capping the raw listing
            #    first lets messages addressed to OTHER sessions (which this turn can never deliver)
            #    consume the quota, starving mine indefinitely behind other conversations' mail.
            #    Caught in test with 2 undeliverable files sorting ahead of a deliverable one.
            $mineFiles = @()
            foreach ($f in @(Get-ChildItem $inboxDir -Filter '*.json' -File | Sort-Object Name)) {
                $m = $null
                try { $m = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { $m = $null }
                if (-not $m -or -not $m.to_session -or -not $m.text) { continue }
                if ([string]$m.to_session -ne $sessionId) { continue }
                $mineFiles += [pscustomobject]@{ File = $f; Text = [string]$m.text }
            }
            foreach ($item in @($mineFiles | Select-Object -First 3)) {
                $f = $item.File
                # 4. DELETE FIRST, emit only what is confirmed gone. This script runs under
                #    SilentlyContinue, so an emit-then-delete order would let a transient lock leave
                #    the file in place with no error and re-inject the same message every prompt for
                #    the whole TTL. Nagging repetition is worse than the silent loss this design
                #    already accepts, so a failed delete must produce silence instead.
                Remove-Item $f.FullName -Force
                if (-not (Test-Path $f.FullName)) { $msgs += $item.Text }
            }
        }
    }
} catch {}

# --- emit ---
if ($changed.Count -eq 0 -and -not $driftNote -and $msgs.Count -eq 0) { exit 0 }
$lines = @()
# Messages lead: they are addressed to a person, not derived state, and the staleness preamble
# talks about files rather than about someone sending you something.
if ($msgs.Count -gt 0) {
    $lines += '[message] From another conversation of yours (delivered once, not stored). Surface this to the user before answering:'
    foreach ($t in $msgs) { $lines += ('  - ' + $t) }
}
if ($changed.Count -gt 0 -or $driftNote) {
    $lines += '[staleness-check] State moved outside this conversation. Re-read the named file(s) before relying on prior context; /reconcile resolves drift.'
    if ($changed.Count -gt 0) { $lines += ('Changed since this session last looked: ' + ($changed -join '; ')) }
    if ($driftNote) { $lines += $driftNote }
}
$payload = @{ hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = ($lines -join "`n") } }
$payload | ConvertTo-Json -Depth 4 -Compress
exit 0
