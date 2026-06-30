#Requires -Version 5.1
# B1 merge-safety + A11 idempotency test for bootstrap/install.ps1.
# Builds a populated fixture ~/.claude, runs install against it, and asserts that NOTHING the
# recipient owned was clobbered -- then runs a second time to prove idempotency. Author-side only.
$ErrorActionPreference = 'Stop'
$Root    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)   # claude-kit repo root
$Install = Join-Path $Root 'bootstrap/install.ps1'
$Fix     = Join-Path $env:TEMP ("kit-fixture-" + (Get-Date -Format 'yyyyMMddHHmmss'))
$fails   = New-Object System.Collections.Generic.List[string]
function Check { param([string]$Name,[bool]$Cond)
  if ($Cond) { Write-Host "  [PASS] $Name" } else { $fails.Add($Name); Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

# --- build a populated, pre-existing ~/.claude fixture --------------------------------------
New-Item -ItemType Directory -Path $Fix -Force | Out-Null
Set-Content (Join-Path $Fix 'settings.json') '{ "model": "FIXTURE-MODEL", "myCustomKey": "keepme", "permissions": { "allow": ["Bash(echo:*)"] }, "extraKnownMarketplaces": { "their-mp": { "source": { "source": "github", "repo": "someone/else" }, "autoUpdate": false } }, "enabledPlugins": { "their-plugin@their-mp": true } }' -Encoding ascii
$origClaude = "# My hand-authored CLAUDE.md`r`nDo not clobber this."
Set-Content (Join-Path $Fix 'CLAUDE.md') $origClaude -Encoding ascii
Set-Content (Join-Path $Fix 'statusline.ps1') '# my existing statusline' -Encoding ascii
New-Item -ItemType Directory -Path (Join-Path $Fix 'threads/active') -Force | Out-Null
Set-Content (Join-Path $Fix 'threads/active/mine.md') 'my thread content' -Encoding ascii
New-Item -ItemType Directory -Path (Join-Path $Fix 'goals/active') -Force | Out-Null
Set-Content (Join-Path $Fix 'goals/active/mine.md') 'my goal content' -Encoding ascii

$h = @{
  claude = (Get-FileHash (Join-Path $Fix 'CLAUDE.md')).Hash
  status = (Get-FileHash (Join-Path $Fix 'statusline.ps1')).Hash
  thread = (Get-FileHash (Join-Path $Fix 'threads/active/mine.md')).Hash
  goal   = (Get-FileHash (Join-Path $Fix 'goals/active/mine.md')).Hash
}

# --- run 1 ---------------------------------------------------------------------------------
& $Install -ClaudeDir $Fix -NonInteractive -SkipExternalPlugins *> $null

Write-Host "== B1 merge-safety =="
Check "CLAUDE.md untouched"                  ((Get-FileHash (Join-Path $Fix 'CLAUDE.md')).Hash -eq $h.claude)
Check "CLAUDE.kit-template.md dropped"       (Test-Path (Join-Path $Fix 'CLAUDE.kit-template.md'))
Check "statusline.ps1 untouched"             ((Get-FileHash (Join-Path $Fix 'statusline.ps1')).Hash -eq $h.status)
Check "thread content untouched"             ((Get-FileHash (Join-Path $Fix 'threads/active/mine.md')).Hash -eq $h.thread)
Check "goal content untouched"               ((Get-FileHash (Join-Path $Fix 'goals/active/mine.md')).Hash -eq $h.goal)
$s = Get-Content (Join-Path $Fix 'settings.json') -Raw | ConvertFrom-Json
Check "scalar conflict kept (model)"         ($s.model -eq 'FIXTURE-MODEL')
Check "extra key preserved (myCustomKey)"    ($s.myCustomKey -eq 'keepme')
Check "array entry preserved (permissions)"  (@($s.permissions.allow) -contains 'Bash(echo:*)')
Check "template key added (effortLevel)"     ($s.effortLevel -eq 'medium')
Check "version stamped (_kitVersion)"        ($null -ne $s._kitVersion)
Check "no template comment-keys leaked"      ($s.PSObject.Properties.Name -notcontains '//')
# auto-update object-of-objects keys: add-if-absent for the kit's entry, preserve the recipient's.
Check "their marketplace preserved"          ($null -ne $s.extraKnownMarketplaces.'their-mp')
Check "kit marketplace added (add-if-absent)" ($null -ne $s.extraKnownMarketplaces.'claude-squidmode')
Check "kit marketplace autoUpdate true"      ($s.extraKnownMarketplaces.'claude-squidmode'.autoUpdate -eq $true)
Check "their enabledPlugin preserved"        ($s.enabledPlugins.'their-plugin@their-mp' -eq $true)
Check "kit plugin enabled (add-if-absent)"   ($s.enabledPlugins.'dimitri-claude-kit@claude-squidmode' -eq $true)
$bk = Get-ChildItem (Join-Path $Fix '.kit-backups') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
Check "backup dir created"                   ($null -ne $bk)
Check "backup holds original settings.json"  ($bk -and (Test-Path (Join-Path $bk.FullName 'settings.json')))
Check "install receipt written"             (Test-Path (Join-Path $Fix '.kit-install-receipt.json'))

# --- run 2 (A11 idempotency) ---------------------------------------------------------------
$hSettings1 = (Get-FileHash (Join-Path $Fix 'settings.json')).Hash
& $Install -ClaudeDir $Fix -NonInteractive -SkipExternalPlugins *> $null
$hSettings2 = (Get-FileHash (Join-Path $Fix 'settings.json')).Hash
Write-Host "== A11 idempotency =="
Check "settings.json byte-identical on 2nd run" ($hSettings2 -eq $hSettings1)

Remove-Item $Fix -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`n== RESULT =="
if ($fails.Count -eq 0) { Write-Host "ALL PASS" -ForegroundColor Green } else { Write-Host ("FAILED: " + ($fails -join '; ')) -ForegroundColor Red; exit 1 }
