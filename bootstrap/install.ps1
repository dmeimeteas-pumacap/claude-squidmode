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
  settingsConflictsKept = @(); arraysAppended = @(); scaffoldDirsCreated = @()
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
          $script:Receipt.settingsConflictsKept += "$key.$($sub.Name)"
          $script:Report.Add("[KEPT] settings.json '$key.$($sub.Name)' = your value (kit wanted '$($sub.Value)'; re-run with -Interactive to choose).")
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
  $settings = if (Test-Path $SettingsTarget) { Get-Content $SettingsTarget -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
  $hasFile = Test-Path $slPath
  $hasKey  = $settings.PSObject.Properties.Name -contains 'statusLine'

  if (($hasFile -or $hasKey) -and -not $IncludeStatusLine) {
    $script:Receipt.statusLine = 'skipped (existing detected)'
    $script:Report.Add("[SKIPPED] statusline left as-is (existing detected). Re-run with -IncludeStatusLine to adopt the kit's (backs yours up first).")
    return
  }
  if (($hasFile -or $hasKey) -and $IncludeStatusLine) {
    if ($hasFile) { Backup-One $slPath }
    if ($hasKey)  { Backup-One $SettingsTarget }
  }
  Copy-Item (Join-Path $PkgRoot 'bootstrap/statusline.ps1') $slPath -Force
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
  if (-not $NonInteractive) {
    $ans = Read-Host "Install optional enhancement plugins ($(($deps.Name) -join ', '))? (Y/n)"
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
