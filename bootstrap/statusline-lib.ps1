# Shared "working in" label derivation, dot-sourced by statusline.ps1 (main
# session bar) and subagent-statusline.ps1 (per-agent panel rows). Both scan a
# transcript tail the same way so the main label and agent labels can never
# drift in methodology.
#
# "working in": the dir work is actively being DONE in, not where Claude was
# launched (the launch repo prints once in the session-start banner instead, and
# hooks/run-from-watch.sh reprints it if the session dir moves). Derived by
# scanning the transcript tail for tool_use paths and labeling each with a
# literal MASTER dir name — git repo basename when inside a repo (.git walk, no
# git fork), else the first segment under the user profile (so ~/.claude work
# reads ".claude", which maps to "general" in thread categorization), else the
# parent dir basename — plus the first-level SUBDIR under that master.
#
# Signal quality rules (a path mention is not "work"):
#   - only paths that EXIST on disk count (kills fragments, fakes, bad escapes)
#   - temp/scratchpad paths never count
#   - WRITE tools (Write/Edit/NotebookEdit) weigh 9; read/search path fields
#     (Read/Grep/Glob) weigh 1; paths inside shell command strings weigh 1.
#     Writes dominate: the label answers "where is Claude CHANGING things",
#     with reads as a fallback signal when a session hasn't written anything.
# Primary = the DOMINANT master (highest weight in the window), not the most
# recent. Other masters need weight >= the significance floor (one write op) to
# count toward the "| +N" tail; one-off touches are ignored. When the primary's
# work concentrates (>=50%) in one subdir, it renders as master/subdir|+n
# (n = other significant subdirs of that master). $null until tool activity
# actually touches files — general conversation alone never sets a label.

$script:labelCache = @{}
$script:profileDir = $env:USERPROFILE

function LabelOf([string]$p) {
  # -> @(master, sub) for a path (file or dir); $null = skip this path.
  if ($script:labelCache.ContainsKey($p)) { return $script:labelCache[$p] }
  $res = $null
  if ($p -notmatch '\\AppData\\Local\\Temp\\' -and (Test-Path -LiteralPath $p)) {
    $root = $null
    $dir = $p
    while ($dir) {
      if (Test-Path -LiteralPath (Join-Path $dir '.git')) { $root = $dir; break }
      $parent = Split-Path -Parent $dir
      if (-not $parent -or $parent -eq $dir) { break }
      $dir = $parent
    }
    if (-not $root -and $script:profileDir -and $p.StartsWith($script:profileDir + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
      $root = Join-Path $script:profileDir (($p.Substring($script:profileDir.Length + 1) -split '\\')[0])
    }
    if (-not $root) { $root = Split-Path -Parent $p }
    if ($root) {
      $master = Split-Path -Leaf $root
      $sub = ''
      if ($p.Length -gt $root.Length + 1) {
        $rest = $p.Substring($root.Length + 1) -split '\\'
        if ($rest.Count -gt 1) { $sub = $rest[0] }   # first-level subdir; root files -> ''
      }
      $res = @($master, $sub)
    }
  }
  $script:labelCache[$p] = $res
  return $res
}

function Get-WorkingLabel([string]$tp) {
  # Transcript path -> plain label string ("master/subdir (+n) | other | +m"),
  # or $null when the transcript is missing/unreadable or holds no path signal.
  if (-not $tp -or -not (Test-Path -LiteralPath $tp)) { return $null }
  try {
    # Tail-read the transcript (last 1 MB) with a share-friendly open; Claude
    # Code appends to this file while the statusline renders. 1 MB (up from
    # 256 KB) because text-heavy stretches (plan mode, long discussions) carry
    # few tool calls per KB — too shallow a tail leaves only bookkeeping noise
    # in the hit window and the label loses the real project.
    $fs = [System.IO.File]::Open($tp, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
      $take = [int][math]::Min($fs.Length, 1048576)
      if ($take -gt 0) { [void]$fs.Seek(-$take, [System.IO.SeekOrigin]::End) }
      $buf = New-Object byte[] $take
      [void]$fs.Read($buf, 0, $take)
    } finally { $fs.Dispose() }
    # Ordered path->repo hits from tool_use entries only (what Claude acts on;
    # tool RESULTS also carry paths but reading output is not "working there").
    # In the raw JSONL a Windows path appears with escaped backslashes (C:\\...).
    $hits = New-Object System.Collections.Generic.List[object]   # entries: @(master, sub, weight)
    foreach ($line in ([System.Text.Encoding]::UTF8.GetString($buf) -split "`n")) {
      if ($line.IndexOf('"type":"tool_use"') -lt 0) { continue }
      # Weight by operation type: mutating tools >> read/search tools. A line
      # can hold several tool_use blocks; any write tool on it promotes the
      # whole line, which errs toward the write (the signal we care about).
      $w = if ($line -match '"name"\s*:\s*"(Write|Edit|MultiEdit|NotebookEdit)"') { 9 } else { 1 }
      foreach ($m in [regex]::Matches($line, '"(?:file_path|notebook_path|path)"\s*:\s*"([A-Za-z]:\\\\[^"]+)"')) {
        $pp = $m.Groups[1].Value -replace '\\{2,}', '\'
        $l = LabelOf $pp
        if ($l) {
          # Session-bookkeeping writes (drafts/memory/eod under ~/.claude) are
          # ABOUT some project, not work IN .claude — the three-tier workflow
          # routes them there from every session. Demote to read weight so they
          # still label a pure-bookkeeping session but never outvote the project
          # the session is actually reading/changing. Plan writes keep full
          # weight on purpose: planning should read as its own activity, and the
          # ".claude/plans" label gets the related project appended below.
          $pw = $w
          if ($pw -gt 1 -and $pp -match '\\\.claude\\(drafts|projects|eod)\\') { $pw = 1 }
          $hits.Add(@($l[0], $l[1], $pw))
        }
      }
      # Shell tool calls carry paths inside the command string, not a path field.
      # A mention is weak evidence of work there, hence the low weight.
      if ($line -match '"name"\s*:\s*"(Bash|PowerShell)"') {
        foreach ($m in [regex]::Matches($line, '[A-Za-z]:\\\\(?:[^"''\s\\;,)\]]|\\\\)+')) {
          $pp = $m.Value -replace '\\{2,}', '\'
          # A bare mention of the ~\.claude root itself is config/hook plumbing
          # (present in nearly every session), not evidence of work there.
          if ($pp.TrimEnd('\') -ieq (Join-Path $script:profileDir '.claude')) { continue }
          $l = LabelOf $pp
          if ($l) { $hits.Add(@($l[0], $l[1], 1)) }
        }
      }
    }
    $win = 40
    if ($hits.Count -gt $win) { $hits = $hits.GetRange($hits.Count - $win, $win) }
    if (-not $hits.Count) { return $null }
    $sigW = 9                       # significance floor: one write op (or a sustained cluster of reads)
    $mW = @{}; $sW = @{}
    foreach ($h in $hits) {
      $mW[$h[0]] = [int]$mW[$h[0]] + $h[2]
      if ($h[1]) { $k = $h[0] + '|' + $h[1]; $sW[$k] = [int]$sW[$k] + $h[2] }
    }
    $primary = ($mW.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
    # Render (format "D3"): master/subdir (+n) | secondMaster | +m
    #   (+n) = other significant subdirs INSIDE the primary (parenthesized,
    #          space-separated); shown only when >=50% of the primary's weight
    #          lands in one first-level subdir.
    #   | secondMaster = the runner-up master named outright; further
    #   significant masters collapse to a bare | +m.
    $lbl = $primary
    $subs = @($sW.GetEnumerator() | Where-Object { $_.Key.StartsWith($primary + '|') } | Sort-Object Value -Descending)
    if ($subs.Count -and $subs[0].Value * 2 -ge $mW[$primary]) {
      $lbl += '/' + $subs[0].Key.Substring($primary.Length + 1)
      $otherSubs = @($subs | Select-Object -Skip 1 | Where-Object { $_.Value -ge $sigW }).Count
      if ($otherSubs) { $lbl += " (+$otherSubs)" }
    }
    # Planning association: when the primary is .claude/plans, the plan is ABOUT
    # whichever project the session is reading — append it with a dot
    # (".claude/plans · TeeTimeBooker"). Taken as the heaviest OTHER master with
    # no significance floor: during light planning the target project may only
    # have a few weight-1 reads, and the association matters most exactly then.
    $assoc = $null
    if ($primary -eq '.claude' -and $lbl.StartsWith('.claude/plans')) {
      $assoc = (@($mW.GetEnumerator() | Where-Object { $_.Key -ne $primary } | Sort-Object Value -Descending) | Select-Object -First 1).Key
      if ($assoc) { $lbl += " $([char]0xB7) $assoc" }
    }
    $ranked = @($mW.GetEnumerator() | Where-Object { $_.Key -ne $primary -and $_.Key -ne $assoc -and $_.Value -ge $sigW } | Sort-Object Value -Descending)
    if ($ranked.Count) {
      $lbl += " | $($ranked[0].Key)"
      if ($ranked.Count -gt 1) { $lbl += " | +$($ranked.Count - 1)" }
    }
    return $lbl
  } catch { return $null }
}
