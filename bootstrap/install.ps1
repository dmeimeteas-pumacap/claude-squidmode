#Requires -Version 5.1
<#
.SYNOPSIS
  Recipient-side bootstrap for dimitri-claude-kit. Installs what a Claude Code plugin CANNOT carry:
  statusLine, user settings (model/theme/effortLevel), external-plugin registration, the
  continuity-file scaffold, and (optionally) the scheduled-/eod task.

.DESCRIPTION
  MERGE-SAFE by invariant: back up first -> add-or-merge -> never overwrite user-owned content ->
  reversible. Idempotent: re-running converges, never duplicates or clobbers. Writes an install
  receipt (~/.claude/.kit-install-receipt.json) recording every addition so a future uninstall is
  clean and version-independent (backup restores overwrites; receipt reverses additions).

.NOTES
  v1 Windows-only. Pre-existing files are restorable from .kit-backups/. Uninstall command is v2.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  # A7: resolve the data dir the SAME way the hooks do, so both halves agree.
  [string] $ClaudeDir = $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }),
  [switch] $InstallEodSchedule,   # opt-in, Windows-only
  [switch] $IncludeStatusLine,    # opt-in: adopt the kit statusline even if recipient has one (backs theirs up)
  [switch] $Interactive,          # prompt on settings scalar conflicts instead of keep-and-report
  [switch] $SkipExternalPlugins,  # don't touch the recipient's plugin set (used by tests + plugin-self-managers)
  [switch] $NonInteractive
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PkgRoot    = Split-Path -Parent $ScriptRoot   # claude-kit repo root
$Stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir  = Join-Path $ClaudeDir ".kit-backups/$Stamp"
$KitVersion = if (Test-Path (Join-Path $PkgRoot 'VERSION')) { (Get-Content (Join-Path $PkgRoot 'VERSION') -Raw).Trim() } else { '0.0.0-dev' }

# Accumulators for the end-of-run summary and the install receipt (B5).
$script:Report  = New-Object System.Collections.Generic.List[string]
$script:Receipt = [ordered]@{
  kitVersion = $KitVersion; installedAt = $Stamp; claudeDir = $ClaudeDir
  backupDir = $null; filesOverwritten = @(); settingsKeysAdded = @()
  settingsConflictsKept = @(); arraysAppended = @(); scaffoldDirsCreated = @(); usageGuide = $null
  tasksRegistered = @(); pluginsInstalled = @(); statusLine = 'untouched'; claudeMd = 'untouched'
  themeCommand = 'untouched'
}

# Write UTF-8 WITHOUT BOM -- Claude Code's JSON parser silently ignores BOM'd files (known gotcha).
function Write-NoBom { param([string] $Path, [string] $Text)
  [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}
function To-Json { param($Obj) ,$Obj | ConvertTo-Json -Depth 20 }
function Json-Eq { param($A, $B) (To-Json $A) -eq (To-Json $B) }

# ---------------------------------------------------------------------------
# Git Bash resolution -- find the REAL Git Bash (not the WSL stub) so install can warn early if it
# is missing. The shipped run-bash-hook.cmd wrapper does the same resolution at hook runtime.
# ---------------------------------------------------------------------------
function Resolve-GitBash {
  $cands = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\usr\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
  )
  $hit = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($hit) { return $hit }
  # fall back to a bash on PATH that is NOT the System32 WSL stub
  $onPath = Get-Command bash -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch '\\System32\\' } | Select-Object -First 1
  if ($onPath) { return $onPath.Source }
  return $null
}

function Assert-GitBash {
  if (Resolve-GitBash) { return }
  $script:Report.Add("[WARN] Git Bash not found. Install Git for Windows so the session-start + expand hooks can run.")
}

# NOTE: the installed plugin's hooks invoke Git Bash through the shipped scripts/run-bash-hook.cmd
# wrapper (resolves Git Bash by absolute path, PATH-order-independent), so no in-place hooks.json
# rewrite is needed and a `claude plugin update` re-ships the working wrapper intact. The old
# Repair-PluginHookPaths patch was removed for this reason (it was wiped by every plugin update).

# ---------------------------------------------------------------------------
# Backup -- always before any write. Timestamped, never overwrites a prior backup.
# ---------------------------------------------------------------------------
function Backup-One { param([string] $Path)
  if (-not (Test-Path $Path)) { return }
  if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
  $rel = $Path.Substring($ClaudeDir.Length).TrimStart('\','/')
  $dest = Join-Path $BackupDir $rel
  New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
  Copy-Item -Path $Path -Destination $dest -Recurse -Force
  $script:Receipt.backupDir = $BackupDir
  $script:Receipt.filesOverwritten += $rel
}

# ---------------------------------------------------------------------------
# settings.json -- MERGE, never replace. Only writes when something actually changes
# (a no-op run never rewrites the recipient's file -> no formatting clobber).
# NOTE: settings.json is tool-managed JSON (no comments), so ConvertTo-Json normalization on a
# real change is benign; the backup is the safety net regardless.
# ---------------------------------------------------------------------------
function Merge-SettingsJson { param([string] $TemplatePath, [string] $TargetPath)
  $tmplText = (Get-Content $TemplatePath -Raw) -replace '__CLAUDE_DIR__', ($ClaudeDir -replace '\\','\\')
  $tmpl = $tmplText | ConvertFrom-Json
  $exists = Test-Path $TargetPath
  $cur = if ($exists) { (Get-Content $TargetPath -Raw | ConvertFrom-Json) } else { [pscustomobject]@{} }
  $changed = $false

  foreach ($p in $tmpl.PSObject.Properties) {
    $key = $p.Name
    if ($key -like '//*') { continue }         # template doc-comment keys never merge into the recipient
    if ($key -eq 'statusLine') { continue }   # A8: statusline handled atomically elsewhere
    $has = $cur.PSObject.Properties.Name -contains $key

    if ($key -in @('hooks','permissions')) {
      # deep-merge object-of-arrays; append only elements not already present (canonical deep-eq).
      if (-not $has) { $cur | Add-Member -NotePropertyName $key -NotePropertyValue $p.Value; $changed = $true; $script:Receipt.settingsKeysAdded += $key; continue }
      foreach ($sub in $p.Value.PSObject.Properties) {
        $curSub = $cur.$key
        if ($curSub.PSObject.Properties.Name -notcontains $sub.Name) {
          $curSub | Add-Member -NotePropertyName $sub.Name -NotePropertyValue $sub.Value; $changed = $true
          $script:Receipt.arraysAppended += "$key.$($sub.Name)"
        } else {
          foreach ($item in @($sub.Value)) {
            $present = @($curSub.($sub.Name)) | Where-Object { Json-Eq $_ $item }
            if (-not $present) { $curSub.($sub.Name) += $item; $changed = $true; $script:Receipt.arraysAppended += "$key.$($sub.Name)" }
          }
        }
      }
      continue
    }

    # object-of-objects keys (declarative marketplace + enabled-plugins): add any sub-key the
    # recipient lacks, keep theirs on conflict + report. This is what makes auto-update reach a
    # recipient who already declares OTHER marketplaces/plugins -- a plain scalar merge would treat
    # the whole object as one conflicting value and skip our entry entirely.
    if ($key -in @('extraKnownMarketplaces','enabledPlugins')) {
      if (-not $has) { $cur | Add-Member -NotePropertyName $key -NotePropertyValue $p.Value; $changed = $true; $script:Receipt.settingsKeysAdded += $key; continue }
      foreach ($sub in $p.Value.PSObject.Properties) {
        if ($cur.$key.PSObject.Properties.Name -notcontains $sub.Name) {
          $cur.$key | Add-Member -NotePropertyName $sub.Name -NotePropertyValue $sub.Value; $changed = $true
          $script:Receipt.settingsKeysAdded += "$key.$($sub.Name)"
        } elseif (-not (Json-Eq $cur.$key.$($sub.Name) $sub.Value)) {
          # 0.1.9 (B2): recurse ONE level further when both sides are objects. INSTALL.md has the
          # recipient run `claude plugin marketplace add` BEFORE this installer, which pre-creates
          # extraKnownMarketplaces.<name> WITHOUT autoUpdate -- so the flat keep-theirs branch here
          # dropped autoUpdate for every recipient, and nobody ever received automatic updates.
          $curEntry = $cur.$key.$($sub.Name)
          if ($curEntry -is [pscustomobject] -and $sub.Value -is [pscustomobject]) {
            $nestedKept = @()
            foreach ($n in $sub.Value.PSObject.Properties) {
              if ($curEntry.PSObject.Properties.Name -notcontains $n.Name) {
                $curEntry | Add-Member -NotePropertyName $n.Name -NotePropertyValue $n.Value; $changed = $true
                $script:Receipt.settingsKeysAdded += "$key.$($sub.Name).$($n.Name)"
              } elseif (-not (Json-Eq $curEntry.$($n.Name) $n.Value)) { $nestedKept += $n.Name }
            }
            if ($nestedKept.Count) {
              $script:Receipt.settingsConflictsKept += @($nestedKept | ForEach-Object { "$key.$($sub.Name).$_" })
              $consequence = if ($nestedKept -contains 'autoUpdate') { " CONSEQUENCE: you will NOT receive automatic kit updates until autoUpdate is true." } else { "" }
              $script:Report.Add("[KEPT] settings.json '$key.$($sub.Name)': your value(s) kept for $($nestedKept -join ', ') (kit differs; re-run with -Interactive to choose).$consequence")
            }
          } else {
            $script:Receipt.settingsConflictsKept += "$key.$($sub.Name)"
            $script:Report.Add("[KEPT] settings.json '$key.$($sub.Name)' = your value (kit wanted '$($sub.Value)'; re-run with -Interactive to choose).")
          }
        }
      }
      continue
    }

    # scalar prefs
    if (-not $has) {
      $cur | Add-Member -NotePropertyName $key -NotePropertyValue $p.Value; $changed = $true
      $script:Receipt.settingsKeysAdded += $key
    } elseif (-not (Json-Eq $cur.$key $p.Value)) {
      if ($Interactive -and -not $NonInteractive) {
        $ans = Read-Host "settings.json '$key': yours='$($cur.$key)' kit='$($p.Value)'. Overwrite with kit value? (y/N)"
        if ($ans -match '^(y|yes)$') { $cur.$key = $p.Value; $changed = $true; $script:Receipt.settingsKeysAdded += "$key (overwritten on confirm)" }
        else { $script:Receipt.settingsConflictsKept += $key; $script:Report.Add("[KEPT] settings.json '$key' = your value '$($cur.$key)' (kit wanted '$($p.Value)').") }
      } else {
        $script:Receipt.settingsConflictsKept += $key
        $script:Report.Add("[KEPT] settings.json '$key' = your value '$($cur.$key)' (kit wanted '$($p.Value)'; re-run with -Interactive to choose).")
      }
    }
  }

  # KIT_VERSION stamp (B4) so the session-start hook can detect version skew.
  if (($cur.PSObject.Properties.Name -notcontains '_kitVersion') -or ($cur._kitVersion -ne $KitVersion)) {
    if ($cur.PSObject.Properties.Name -contains '_kitVersion') { $cur._kitVersion = $KitVersion } else { $cur | Add-Member -NotePropertyName '_kitVersion' -NotePropertyValue $KitVersion }
    $changed = $true
  }

  if ($changed) {
    if ($exists) { Backup-One $TargetPath }
    Write-NoBom $TargetPath (To-Json $cur)
    $script:Report.Add("[MERGED] settings.json updated (backup in .kit-backups/$Stamp/).")
  }
}

# ---------------------------------------------------------------------------
# CLAUDE.md -- NEVER overwrite an existing one.
# ---------------------------------------------------------------------------
function Install-ClaudeTemplate { param([string] $TemplatePath, [string] $TargetPath)
  if (Test-Path $TargetPath) {
    $alt = Join-Path $ClaudeDir 'CLAUDE.kit-template.md'
    Copy-Item $TemplatePath $alt -Force
    $script:Receipt.claudeMd = 'left intact; template dropped as CLAUDE.kit-template.md'
    $script:Report.Add("[SKIPPED] CLAUDE.md left intact. Kit template dropped at CLAUDE.kit-template.md -- merge the behavioral sections by hand if you want them.")
    # R5-11 (0.1.10): say WHICH sections they are missing, by name. Still no merge -- never touching a
    # user's CLAUDE.md is the invariant -- but silence here meant an upgrading user whose CLAUDE.md is
    # itself an older copy of this template never learned a new section existed. Measured in the
    # sandbox: a behavioural rule added in 0.1.9 (offer the guide + /kit) never reached that profile,
    # and the vetting round failed the check that rule was written to satisfy.
    try {
      $hdr = { param($P) @(Select-String -Path $P -Pattern '^##\s+(.+?)\s*$' |
                           ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }) }
      $tmplSections = & $hdr $TemplatePath
      $userSections = & $hdr $TargetPath
      $missing = @($tmplSections | Where-Object { $userSections -notcontains $_ })
      if ($missing.Count) {
        $script:Receipt.claudeMdMissingSections = $missing
        $shown = if ($missing.Count -le 4) { $missing -join '; ' } else { (($missing | Select-Object -First 4) -join '; ') + "; +$($missing.Count - 4) more" }
        $script:Report.Add("[REVIEW] Your CLAUDE.md is missing $($missing.Count) section(s) the kit template now carries: $shown. These are behavioural rules the kit's skills assume -- copy the ones you want from CLAUDE.kit-template.md.")
      }
    } catch {}
  } else {
    Copy-Item $TemplatePath $TargetPath -Force
    $script:Receipt.claudeMd = 'installed (was absent)'
    $script:Report.Add("[INSTALLED] CLAUDE.md (none existed).")
  }
}

# ---------------------------------------------------------------------------
# statusLine -- A8: one atomic decision over the FILE (statusline.ps1) + the settings 'statusLine' key.
# ---------------------------------------------------------------------------
function Install-StatusLine { param([string] $SettingsTarget)
  $slPath = Join-Path $ClaudeDir 'statusline.ps1'
  $slLib  = Join-Path $ClaudeDir 'statusline-lib.ps1'
  $libSrc = Join-Path $PkgRoot 'bootstrap/statusline-lib.ps1'
  $settings = if (Test-Path $SettingsTarget) { Get-Content $SettingsTarget -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
  $hasFile = Test-Path $slPath
  $hasKey  = $settings.PSObject.Properties.Name -contains 'statusLine'

  if (($hasFile -or $hasKey) -and -not $IncludeStatusLine) {
    # 0.1.9 (B1): a statusline installed by kit 0.1.7/0.1.8 dot-sources statusline-lib.ps1, which
    # those versions never shipped. Repair that one case here: add-only, never touches an existing
    # file, and skips statuslines that don't reference the lib (i.e. the user's own).
    if ($hasFile -and (Test-Path $libSrc) -and -not (Test-Path $slLib) -and
        ((Get-Content $slPath -Raw) -match 'statusline-lib\.ps1')) {
      Copy-Item $libSrc $slLib -Force
      $script:Receipt.statusLine = 'skipped (existing detected); statusline-lib.ps1 added (required by it, was missing)'
      $script:Report.Add("[REPAIRED] statusline-lib.ps1 installed -- your statusline.ps1 requires it and it was missing (kit 0.1.7/0.1.8 defect).")
      return
    }
    $script:Receipt.statusLine = 'skipped (existing detected)'
    $script:Report.Add("[SKIPPED] statusline left as-is (existing detected). Re-run with -IncludeStatusLine to adopt the kit's (backs yours up first).")
    return
  }
  if (($hasFile -or $hasKey) -and $IncludeStatusLine) {
    if ($hasFile) { Backup-One $slPath }
    if (Test-Path $slLib) { Backup-One $slLib }
    if ($hasKey)  { Backup-One $SettingsTarget }
  }
  Copy-Item (Join-Path $PkgRoot 'bootstrap/statusline.ps1') $slPath -Force
  if (Test-Path $libSrc) { Copy-Item $libSrc $slLib -Force }   # B1: the bar dot-sources this lib
  $themesDir = Join-Path $ClaudeDir 'themes'; New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
  Copy-Item (Join-Path $PkgRoot 'bootstrap/themes/cc-active.json') (Join-Path $themesDir 'cc-active.json') -Force
  # wire the settings key (atomic with the file)
  $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$slPath`""
  $sl = [pscustomobject]@{ type = 'command'; command = $cmd; padding = 0 }
  if ($hasKey) { $settings.statusLine = $sl } else { $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $sl }
  Write-NoBom $SettingsTarget (To-Json $settings)
  $script:Receipt.statusLine = 'adopted'
  $script:Report.Add("[INSTALLED] statusline adopted + wired.")
}

# ---------------------------------------------------------------------------
# /theme user command -- a USER-level ~/.claude/commands/theme.md makes BARE `/theme` run the
# custom statusline picker. The plugin only provides the namespaced /dimitri-claude-kit:theme;
# the bare command needs the user-level copy. (Live install missed this because the user commands
# dir shipped empty.) Merge-safe: install only if absent; never overwrite a recipient's own.
# ---------------------------------------------------------------------------
function Install-ThemeCommand {
  $src = Join-Path $PkgRoot 'plugins/dimitri-claude-kit/commands/theme.md'
  if (-not (Test-Path $src)) { return }
  $cmdDir = Join-Path $ClaudeDir 'commands'
  if (-not (Test-Path $cmdDir)) { New-Item -ItemType Directory -Path $cmdDir -Force | Out-Null }
  $dst = Join-Path $cmdDir 'theme.md'
  if (Test-Path $dst) {
    $script:Receipt.themeCommand = 'skipped (existing)'
    $script:Report.Add("[SKIPPED] commands/theme.md exists -- left as-is. Bare /theme uses your copy; the kit's is at $src.")
    return
  }
  Copy-Item $src $dst -Force
  $script:Receipt.themeCommand = 'installed'
  $script:Report.Add("[INSTALLED] commands/theme.md -- bare /theme now opens the custom palette picker (restart to load).")
}

# ---------------------------------------------------------------------------
# Usage guide -- copy to a STABLE human-openable path.
#
# The guide also ships inside the plugin, which is where /kit reads it from. That plugin copy is NOT
# usable by a person: installed plugins land under
# ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/, a leaf that changes every release, so it
# cannot go in a doc or a bookmark. So we copy it to ~/.claude/guide/ and every human-facing doc cites
# that path only. This is a copy of a shipped artifact, never a second authored source -- it is
# overwritten wholesale on re-install, and there is nothing in it a user would edit.
# ---------------------------------------------------------------------------
# N1 (0.1.9.1): this refresh used to Remove-Item -Recurse the whole guide dir on every run. Under the
# script-wide $ErrorActionPreference='Stop' a locked dir (a terminal parked in guide/, a page open in
# an editor -- the kit TELLS people to open these) threw and aborted the entire installer AFTER the
# statusline + settings work, so the receipt was never written and the run failed silently.
# Fixed three ways: (1) no-op when content already matches, so the common re-run touches nothing;
# (2) copy OVER the top + sweep orphans instead of delete-then-recreate, so holding the directory
# open no longer blocks anything; (3) the whole thing is non-fatal -- a failure reports and lets the
# install finish, receipt included.
function Install-UsageGuide {
  $src = Join-Path $PkgRoot 'plugins/dimitri-claude-kit/guide'
  if (-not (Test-Path $src)) { $script:Report.Add("[SKIPPED] usage guide not present in the package."); return }
  $dst = Join-Path $ClaudeDir 'guide'
  $fresh = -not (Test-Path $dst)

  # Relative-path keys MUST come from a root normalized the same way Get-ChildItem normalizes
  # FullName, or the Substring offset is wrong and every key mismatches. Caught in test: -ClaudeDir
  # given as an 8.3 short path ('...\DMEIME~1\...') while FullName expands to the long name, which
  # made the orphan sweep below delete the files it had just copied. (Get-Item).FullName expands
  # short names and settles separators/trailing slashes for both sides.
  $rel = { param($Root, $F) $F.FullName.Substring($Root.Length).TrimStart('\','/') }
  $srcRoot = (Get-Item $src).FullName.TrimEnd('\','/')

  # Content compare (relative path + hash). Identical -> nothing to do; never open the write window.
  # MUST be non-fatal: Get-FileHash on a locked page throws under the script-wide -Stop preference,
  # which would abort the installer before the receipt is written -- the very N1 failure this function
  # exists to fix, just moved earlier. Caught in test with an exclusive handle on index.html. On any
  # read failure, fall through as "changed" and let the guarded copy below report it.
  if (-not $fresh) {
    $same = $false
    try {
      # -ErrorAction SilentlyContinue, not the ambient -Stop: a locked page otherwise writes a raw
      # PowerShell error record to stderr even though the catch below handles it, so the user saw a
      # friendly [SKIPPED] line AND a red stack trace for the same event (0.1.9.1 finding R5-5).
      # A null hash means unreadable, which counts as "changed" and falls through to the guarded copy.
      $dstRootCmp = (Get-Item $dst).FullName.TrimEnd('\','/')
      $srcMap = @{}; $dstMap = @{}
      foreach ($f in @(Get-ChildItem $src -Recurse -File)) { $srcMap[(& $rel $srcRoot $f)] = (Get-FileHash $f.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash }
      foreach ($f in @(Get-ChildItem $dst -Recurse -File)) { $dstMap[(& $rel $dstRootCmp $f)] = (Get-FileHash $f.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash }
      $same = $srcMap.Count -eq $dstMap.Count
      if ($same) {
        foreach ($k in $srcMap.Keys) {
          if (-not $srcMap[$k] -or -not $dstMap[$k] -or ($dstMap[$k] -ne $srcMap[$k])) { $same = $false; break }
        }
      }
    } catch { $same = $false }
    if ($same) {
      $script:Receipt.usageGuide = 'guide (unchanged)'
      $script:Report.Add("[UNCHANGED] guide/ -- already current ($($srcMap.Count) files). Open $dst\index.html in a browser; no Claude session needed.")
      return
    }
  }

  try {
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    Copy-Item (Join-Path $src '*') $dst -Recurse -Force   # overwrite in place; no dir delete
    # Sweep files the package no longer ships (a renamed/removed page would otherwise linger).
    $keep = @{}
    foreach ($f in @(Get-ChildItem $src -Recurse -File)) { $keep[(& $rel $srcRoot $f)] = $true }
    # Safety: an empty keep-set can only mean the key derivation broke, never "the package ships no
    # guide files" (Test-Path above already proved otherwise). Deleting on that basis would wipe the
    # guide, so skip the sweep instead -- a stale leftover is strictly cheaper than a wrong delete.
    if ($keep.Count -gt 0) {
      $dstRoot = (Get-Item $dst).FullName.TrimEnd('\','/')
      foreach ($f in @(Get-ChildItem $dst -Recurse -File)) {
        $r = & $rel $dstRoot $f
        if (-not $keep.ContainsKey($r)) {
          try { Remove-Item $f.FullName -Force } catch { $script:Report.Add("[WARN] guide/: could not remove stale '$r' ($($_.Exception.Message)).") }
        }
      }
    } else {
      $script:Report.Add("[WARN] guide/: orphan sweep skipped (could not derive relative paths).")
    }
    $n = @(Get-ChildItem $dst -Filter '*.html' -File).Count
    $script:Receipt.usageGuide = 'guide'
    $verb = if ($fresh) { 'INSTALLED' } else { 'REFRESHED' }
    $script:Report.Add("[$verb] guide/ -- $n pages. Open $dst\index.html in a browser; no Claude session needed.")
  } catch {
    # NEVER fatal: the guide is a convenience copy, and aborting here loses the install receipt.
    $script:Receipt.usageGuide = "failed: $($_.Exception.Message)"
    $script:Report.Add("[SKIPPED] guide/ could not be written -- something is holding it open (a terminal parked in guide\, or a page open in an editor). Close it and re-run the installer; everything else installed normally. ($($_.Exception.Message))")
  }
}

# ---------------------------------------------------------------------------
# Continuity scaffold -- empty dirs only, never seed personal content.
# ---------------------------------------------------------------------------
function Initialize-ContinuityScaffold {
  $dirs = 'threads/active','threads/done','memory','session-notes/auto','goals/active','goals/done'
  foreach ($d in $dirs) {
    $full = Join-Path $ClaudeDir $d
    if (-not (Test-Path $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null; $script:Receipt.scaffoldDirsCreated += $d }
  }
  $idx = Join-Path $ClaudeDir 'threads/INDEX.md'
  if (-not (Test-Path $idx)) { Write-NoBom $idx "# Threads`n_Updated by /log._`n`n## Active`n`n## Paused`n`n## Recently done (last 30 days)`n" }
  $mem = Join-Path $ClaudeDir 'memory/MEMORY.md'
  if (-not (Test-Path $mem)) { Write-NoBom $mem "# Memory Index`n" }
  if ($script:Receipt.scaffoldDirsCreated.Count) { $script:Report.Add("[CREATED] continuity scaffold: $($script:Receipt.scaffoldDirsCreated -join ', ').") }
}

# ---------------------------------------------------------------------------
# External plugin deps (optional enhancements; core skills do NOT hard-depend).
# ---------------------------------------------------------------------------
function Install-ExternalPlugins {
  if ($SkipExternalPlugins) { $script:Report.Add("[SKIPPED] external plugins (-SkipExternalPlugins)"); return }
  # Each enhancement must have its MARKETPLACE registered before 'plugin install' can resolve it.
  # (The earlier bug: we ran 'plugin install andrej-karpathy-skills' with no marketplace added, so
  # it never resolved.) code-simplifier ships from the built-in 'claude-plugins-official' marketplace,
  # so it needs no add.
  $deps = @(
    [pscustomobject]@{ Name = 'andrej-karpathy-skills'; Marketplace = 'forrestchang/andrej-karpathy-skills' },
    [pscustomobject]@{ Name = 'code-simplifier';        Marketplace = $null }
  )
  $manualCmd = {
    param($d)
    if ($d.Marketplace) { "claude plugin marketplace add $($d.Marketplace) ; claude plugin install $($d.Name)" }
    else { "claude plugin install $($d.Name)" }
  }
  $claude = Get-Command claude -ErrorAction SilentlyContinue
  if (-not $claude) {
    $cmds = ($deps | ForEach-Object { & $manualCmd $_ }) -join ' ; '
    $script:Report.Add("[MANUAL] Optional enhancements -- install yourself: $cmds")
    return
  }
  # A bare Read-Host in a non-interactive host (CI, a scripted install, `powershell -NonInteractive`)
  # THROWS under the script-wide -Stop preference, aborting the installer after the statusline and
  # settings work with no summary and a stale receipt -- the identical failure shape N1 fixed in the
  # guide block (0.1.9.1 finding R5-4).
  # MEASURED: [Environment]::UserInteractive returns TRUE under `powershell -NonInteractive`, so the
  # cheap host check does NOT catch that case -- the try/catch below is the load-bearing fix, and the
  # UserInteractive branch only helps in a genuinely non-interactive context (a service, no window
  # station). Keep both; do not "simplify" by deleting the catch.
  if (-not $NonInteractive -and -not [Environment]::UserInteractive) {
    $script:Report.Add("[SKIPPED] optional-plugin prompt (non-interactive host detected; installing deps merge-safely as if -NonInteractive).")
  } elseif (-not $NonInteractive) {
    $ans = $null
    try { $ans = Read-Host "Install optional enhancement plugins ($(($deps.Name) -join ', '))? (Y/n)" }
    catch {
      $script:Report.Add("[SKIPPED] optional-plugin prompt could not be shown ($($_.Exception.Message.Split([char]10)[0])). Continuing; re-run with -NonInteractive to silence this.")
      return
    }
    if ($ans -match '^(n|no)$') { $script:Report.Add("[SKIPPED] external enhancement plugins (declined)."); return }
  }
  foreach ($d in $deps) {
    try {
      if ($d.Marketplace) { & claude plugin marketplace add $d.Marketplace 2>$null }
      & claude plugin install $d.Name 2>$null
      $script:Receipt.pluginsInstalled += $d.Name
    } catch {
      $script:Report.Add("[MANUAL] '$($d.Name)' install failed -- run: $(& $manualCmd $d)")
    }
  }
}

# ---------------------------------------------------------------------------
# Optional: scheduled /eod (Windows-only, opt-in). Runs Claude ~twice daily against YOUR usage.
# ---------------------------------------------------------------------------
function Install-EodScheduleOptional {
  if (-not $InstallEodSchedule) { return }
  $setup = Join-Path $ClaudeDir 'scripts/setup-eod-schedule.ps1'
  if (-not (Test-Path $setup)) { Copy-Item (Join-Path $PkgRoot 'bootstrap/scripts/setup-eod-schedule.ps1') $setup -Force }
  $taskNames = @('ClaudeEOD-Afternoon','ClaudeEOD-Evening')
  try {
    & $setup   # idempotent; registers ClaudeEOD-Afternoon/Evening only if absent
  } catch {
    $script:Report.Add("[FAILED] scheduled /eod setup raised: $($_.Exception.Message)")
  }
  # Record VERIFIED outcome, never intent: query the scheduler and report only tasks that truly
  # exist. Register-ScheduledTask fails with Access denied (0x80070005) on a domain-joined machine
  # unless the shell is elevated, so a non-elevated run can silently register nothing.
  $registered = @($taskNames | Where-Object { Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue })
  $script:Receipt.tasksRegistered = $registered
  $missing = @($taskNames | Where-Object { $_ -notin $registered })
  if ($missing.Count -eq 0) {
    $script:Report.Add("[INSTALLED] scheduled /eod ($($registered -join ', ')) -- runs Claude ~2x/day against your usage; remove via schtasks /delete /tn ClaudeEOD-*.")
  } else {
    $script:Receipt.tasksFailed = $missing
    $script:Report.Add("[FAILED] scheduled /eod NOT registered: $($missing -join ', '). Task creation on a domain-joined machine needs elevation -- re-run this installer (or scripts/setup-eod-schedule.ps1) from an ELEVATED PowerShell.")
  }
}

# ---------------------------------------------------------------------------
# Orchestration.
# ---------------------------------------------------------------------------
function Invoke-Bootstrap {
  Write-Host "== dimitri-claude-kit bootstrap (v$KitVersion) ->  $ClaudeDir =="
  $settingsTarget = Join-Path $ClaudeDir 'settings.json'
  $tmplSettings   = Join-Path $PkgRoot 'bootstrap/settings.template.json'
  $tmplClaude     = Join-Path $PkgRoot 'bootstrap/CLAUDE.template.md'
  $claudeTarget   = Join-Path $ClaudeDir 'CLAUDE.md'

  Assert-GitBash
  Install-StatusLine -SettingsTarget $settingsTarget   # before Merge: settles the statusLine key
  Merge-SettingsJson -TemplatePath $tmplSettings -TargetPath $settingsTarget
  Install-ClaudeTemplate -TemplatePath $tmplClaude -TargetPath $claudeTarget
  Install-ThemeCommand
  Install-UsageGuide
  Initialize-ContinuityScaffold
  Install-ExternalPlugins
  Install-EodScheduleOptional

  # Receipt (B5) -- enables a clean, version-independent v2 uninstall.
  Write-NoBom (Join-Path $ClaudeDir '.kit-install-receipt.json') (To-Json $script:Receipt)

  Write-Host "`n-- install summary -------------------------------------------------"
  if ($script:Report.Count -eq 0) { Write-Host "  (nothing to change -- already up to date)" }
  else { $script:Report | ForEach-Object { Write-Host "  $_" } }
  Write-Host "  Backup (overwrites only): $(if ($script:Receipt.backupDir) { $script:Receipt.backupDir } else { '(none needed)' })"
  Write-Host "  Receipt: $ClaudeDir\.kit-install-receipt.json"
  Write-Host "--------------------------------------------------------------------"
  Write-Host "Done. Restart Claude Code so the plugin hooks + statusline load."
  Write-Host "New here? After restarting, run /tutorial for a guided, hands-on walkthrough of the kit."
}

Invoke-Bootstrap
