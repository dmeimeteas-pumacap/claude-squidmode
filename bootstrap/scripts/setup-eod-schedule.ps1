#requires -Version 5.1
<#
.SYNOPSIS
  Installs (or re-creates) the daily /eod scheduled tasks on Windows.
.DESCRIPTION
  Idempotent. Writes the launcher (run-eod.ps1) and registers two weekday tasks
  (ClaudeEOD-Afternoon, ClaudeEOD-Evening) that run the local /eod skill headless
  Mon-Fri, with opt-out and nothing-changed skip guards in the launcher.
  Safe to re-run. See README-eod-schedule.md for full details and teardown.

  Transfer to another Windows machine: copy this file and run it. Nothing else
  is machine-specific -- the launcher resolves claude.exe from PATH at runtime.
.PARAMETER AfternoonTime
  HH:mm for the first daily run. Default 16:30.
.PARAMETER EveningTime
  HH:mm for the backstop run (covers work done after the afternoon run; /eod
  overwrites, so last run wins). Default 21:00.
#>
param(
  [string]$AfternoonTime = "16:30",
  [string]$EveningTime   = "21:00"
)
$ErrorActionPreference = "Stop"

$scripts = Join-Path $env:USERPROFILE ".claude\scripts"
if (-not (Test-Path $scripts)) { New-Item -ItemType Directory -Path $scripts | Out-Null }
$wrapper = Join-Path $scripts "run-eod.ps1"

# Launcher (PowerShell). Holds the skip guards, then launches /eod headless.
# Guards apply to SCHEDULED runs only; a manual `claude -p /eod` or interactive /eod is unguarded.
# bypassPermissions is REQUIRED: /eod writes under ~/.claude, a sensitive path that acceptEdits
# will not auto-approve in a headless run. Resolves claude.exe from PATH first (portable), then
# falls back to the default install location. Written ASCII (no BOM).
$launcher = @'
#requires -Version 5.1
# Daily EOD synthesis launcher with skip guards (Windows Task Scheduler).
# Guards apply to SCHEDULED runs only. See README-eod-schedule.md.
param([switch]$Scheduled)
$ErrorActionPreference = "Stop"
$claudeDir = Join-Path $env:USERPROFILE ".claude"

# Keep the console open after a manual/attended run so its output can be read before the window
# closes. Gated on -not $Scheduled: an Interactive-logon scheduled task ALSO reports
# UserInteractive=$true, so gating on UserInteractive alone hangs the unattended run on Read-Host
# (-> TASK_TERMINATED 0x41306). The scheduler passes -Scheduled; a manual double-click does not.
try {

# --- Guard 1: manual opt-out sentinel (~/.claude/.eod-skip) ---
#   empty / non-date content -> skip until the file is deleted
#   a date (YYYY-MM-DD)       -> skip through that date, then auto-clear
$skipFile = Join-Path $claudeDir ".eod-skip"
if (Test-Path $skipFile) {
  $val = ""
  try { $val = ((Get-Content $skipFile -Raw) -replace "\s","") } catch {}
  if ($val) {
    $until = [datetime]::MinValue
    if ([datetime]::TryParse($val, [ref]$until)) {
      if ((Get-Date).Date -le $until.Date) { Write-Host "Skip: .eod-skip active through $($until.ToString('yyyy-MM-dd'))"; exit 0 }
      Remove-Item $skipFile -Force -ErrorAction SilentlyContinue
      Write-Host "Cleared expired .eod-skip ($($until.ToString('yyyy-MM-dd')))"
    } else { Write-Host "Skip: .eod-skip present"; exit 0 }
  } else { Write-Host "Skip: .eod-skip present (no date)"; exit 0 }
}

# --- Guard 2 (weekend): enforced at the Mon-Fri trigger; no code needed here. ---

# --- Guard 3: nothing changed since the last eod ---
# Activity = newest of thread .md files + JSONL transcripts under repo project folders.
# The home folder (computed from $env:USERPROFILE) is EXCLUDED: eod's own headless runs (and home-dir
# sessions) write transcripts there, which would otherwise always look like fresh activity.
$eodLatest = Join-Path $claudeDir "session-notes\eod-latest.md"
if (Test-Path $eodLatest) {
  $eodTime = (Get-Item $eodLatest).LastWriteTime
  $items = @()
  $threadsDir = Join-Path $claudeDir "threads"
  if (Test-Path $threadsDir) { $items += Get-ChildItem $threadsDir -Recurse -File -Filter *.md -ErrorAction SilentlyContinue }
  $projDir = Join-Path $claudeDir "projects"
  if (Test-Path $projDir) {
    $homeProj = ($env:USERPROFILE -replace '[^A-Za-z0-9]','-')
    $items += Get-ChildItem $projDir -Recurse -File -Filter *.jsonl -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -notmatch "\\projects\\$homeProj\\" }
  }
  if ($items.Count -gt 0) {
    $newest = ($items | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
    if ($newest -le $eodTime) { Write-Host "Skip: no activity since last eod ($($eodTime.ToString('yyyy-MM-dd HH:mm')))"; exit 0 }
  }
}

# --- Guard 4: cooldown -- skip a SCHEDULED run if eod ran very recently (e.g. a manual run
# minutes earlier). 30 min absorbs a manual run near a scheduled one without touching the
# 4.5h afternoon->evening gap. Scheduled-only so a deliberate manual relaunch is never blocked.
if ($Scheduled -and (Test-Path $eodLatest)) {
  $age = (Get-Date) - (Get-Item $eodLatest).LastWriteTime
  if ($age.TotalMinutes -lt 30) { Write-Host ("Skip: eod ran {0:N0} min ago (<30 min cooldown)" -f $age.TotalMinutes); exit 0 }
}

# --- Guard 0: token budget -- skip if usage is near the cap (don't spend credits) ---
# Reads ~/.claude/.rate-limit-state.json, written by statusline.ps1 on each render
# (the only place Claude Code's usage signal is exposed; it lives nowhere else on disk).
# Skip if five_hour >= 90% OR seven_day >= 95%. The state is only as fresh as the last
# interactive session, so the post-launch backstop below catches a stale "all clear".
$rlState = Join-Path $claudeDir ".rate-limit-state.json"
if (Test-Path $rlState) {
  try {
    $rl = Get-Content $rlState -Raw | ConvertFrom-Json
    if (($rl.five_hour -ge 90) -or ($rl.seven_day -ge 95)) {
      Write-Host ("Skip: token usage high (5h {0}%, wk {1}%, as of {2})" -f $rl.five_hour, $rl.seven_day, $rl.ts)
      exit 0
    }
  } catch {}
}

# --- Launch ---
Set-Location $env:USERPROFILE
$claudeExe = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claudeExe) { $claudeExe = Join-Path $env:USERPROFILE ".local\bin\claude.exe" }
# Backstop for a stale Guard 0: if the run hits a rate-limit/quota error, exit cleanly
# without retrying. A truly-exhausted account errors near-instantly (near-zero spend).
$eodOut = & $claudeExe -p "/eod" --permission-mode bypassPermissions 2>&1 | Out-String
$code = $LASTEXITCODE
Write-Host $eodOut
if ($code -ne 0 -and $eodOut -match '(?i)rate.?limit|usage limit|quota|exceeded|insufficient|out of') {
  Write-Host "Skip(backstop): claude reported a limit/quota error -- not retrying."
  exit 0
}
exit $code

}
finally {
  if (-not $Scheduled -and [Environment]::UserInteractive) { Read-Host "`nEOD launcher finished -- press Enter to close" | Out-Null }
}
'@
Set-Content -Path $wrapper -Value $launcher -Encoding ASCII
Write-Host "Wrote launcher: $wrapper"

# StartWhenAvailable    -> run after a missed start (machine was asleep/off at the time).
# AllowStartIfOnBatteries + DontStopIfGoingOnBatteries -> the default would skip/stop on battery.
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
# Launcher is PowerShell now -> invoke via powershell.exe with the script file.
$psExe     = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$action    = New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper`" -Scheduled"
# Interactive logon -> runs only when you are logged on, so it inherits your Claude credentials.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive

# Weekdays only (Mon-Fri): the weekend skip is enforced here at the trigger, so claude never launches Sat/Sun.
$weekdays = @("Monday","Tuesday","Wednesday","Thursday","Friday")
foreach ($t in @(
  @{ Name = "ClaudeEOD-Afternoon"; Time = $AfternoonTime },
  @{ Name = "ClaudeEOD-Evening";   Time = $EveningTime  }
)) {
  $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $weekdays -At ([datetime]$t.Time)
  Register-ScheduledTask -TaskName $t.Name -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
  Write-Host "Registered $($t.Name) (Mon-Fri $($t.Time))"
}
Write-Host "Done."
