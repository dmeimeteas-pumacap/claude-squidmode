#Requires -Version 5.1
<#
.SYNOPSIS
  Author-side rebuild: re-derive the shippable claude-kit from the live ~/.claude, staging to an
  isolated temp dir, HARD-FAILING on any personal-data leak before anything reaches the repo.
  Then commit + push. This is the "patch the export" loop.

.DESCRIPTION
  ALLOWLIST model (B3): only files in $ShipSkills/$ShipCommands/$ShipHooks/$BootstrapAssets are copied.
  Build proceeds: clean stage -> sync into stage -> Assert-NoPersonalData on stage (hard fail) ->
  promote stage into the repo. The live ~/.claude is never git-added; a tainted stage never promotes.
.NOTES
  Mirrors PACKAGE-MANIFEST.md. ASCII-only by policy (PS 5.1 reads BOM-less .ps1 as ANSI).
#>

[CmdletBinding()]
param(
  [string] $ClaudeDir = (Join-Path $env:USERPROFILE '.claude'),
  [string] $RepoRoot  = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
  [string] $Version   # defaults to the VERSION file (the single source of truth); -Version overrides
)
$ErrorActionPreference = 'Stop'
if (-not $Version) {
  $vf = Join-Path $RepoRoot 'VERSION'
  $Version = if (Test-Path $vf) { (Get-Content $vf -Raw).Trim() } else { '0.1.0' }
}

# --- ALLOWLIST (executable source of truth; mirrors PACKAGE-MANIFEST.md) -------------------
$ShipSkills = @('catchup','catchupall','change-review','document-process',
  'document-section','eod','eow','goals','grill-me','log','logall','skill-builder','scrutinize','today','tutorial')
$ExcludeSkills   = @('maystreet-pull','test-safety-audit','document-overall')   # coupled/local -- never ship. (today ships since v0.1.6: the DAY door, CLI-free. update-statuses/current/task-tracker skills deleted 2026-07-31, folded into reconcile//goals//today.)
$ShipCommands    = @('theme.md')
$ShipHooks       = @('session-start-global.sh','expand-prompt.sh')
$BootstrapAssets = @(
  @{ src='statusline.ps1';                 dst='statusline.ps1' },
  @{ src='themes/cc-active.json';          dst='themes/cc-active.json' },
  @{ src='scripts/setup-eod-schedule.ps1'; dst='scripts/setup-eod-schedule.ps1' },
  @{ src='scripts/run-eod.ps1';            dst='scripts/run-eod.ps1' }
)
$ShipDocs  = @('QUICKSTART.md','GUIDE.md','INSTALL.md','LITE.md','README.md','PACKAGE-MANIFEST.md')
$PluginRel = 'plugins/dimitri-claude-kit'

# Personal-data leak markers (specific, low false-positive). Any hit HARD-FAILS the build.
$LeakPatterns = @('dmeimeteas','tjyoptions','pumacap','PumaCap',
  'C:\\Users\\dmeimeteas','/c/Users/dmeimeteas','[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')

# Allowlist: substrings that legitimately ship even though they contain leak markers. ONLY the
# kit's own public distribution repo -- the declarative auto-update entry in settings.template.json
# REQUIRES the concrete repo path, and recipients already have this URL from `marketplace add`.
# Stripped from each file's text before scanning, so a stray 'dmeimeteas'/'pumacap' elsewhere still
# hard-fails. Keep this list to genuinely-public identifiers only.
$LeakAllowList = @('dmeimeteas-pumacap/claude-squidmode')

$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Stage = Join-Path $env:TEMP "claude-kit-build-$Stamp"
$Report = New-Object System.Collections.Generic.List[string]

function Write-NoBom { param([string] $Path, [string] $Text)
  $dir = Split-Path -Parent $Path; if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}
function Stage-Path { param([string] $Rel) Join-Path $Stage $Rel }

function Sync-Skills {
  $destRoot = Stage-Path "$PluginRel/skills"
  foreach ($s in $ShipSkills) {
    if ($ExcludeSkills -contains $s) { continue }
    $src = Join-Path $ClaudeDir "skills/$s"
    if (-not (Test-Path $src)) { throw "Allowlisted skill '$s' not found at $src" }
    Copy-Item $src (Join-Path $destRoot $s) -Recurse -Force
  }
  $Report.Add("skills: shipped $($ShipSkills.Count), excluded $($ExcludeSkills -join ', ')")
}

function Sync-Commands {
  $destRoot = Stage-Path "$PluginRel/commands"
  New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
  foreach ($c in $ShipCommands) {
    $src = Join-Path $ClaudeDir "commands/$c"
    if (Test-Path $src) { Copy-Item $src (Join-Path $destRoot $c) -Force }
  }
  $Report.Add("commands: $($ShipCommands -join ', ')")
}

function Sync-Hooks {
  $destRoot = Stage-Path "$PluginRel/scripts"
  New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
  $oldDeriv = 'CLAUDE_DIR="$(cd "$HOOK_DIR/.." && pwd)"'
  # D1 (robust): the author's live hook lives at ~/.claude/hooks, so "$HOOK_DIR/.." works there.
  # Once installed as a PLUGIN the hook lives at ~/.claude/plugins/.../scripts, where "$HOOK_DIR/.."
  # points at the plugin dir, NOT ~/.claude -- so the thread INDEX is never found. Resolve in order:
  # explicit CLAUDE_CONFIG_DIR -> derive from the /plugins/ path BUT ONLY when that strip lands on a
  # real .claude dir -> $HOME/.claude -> $USERPROFILE/.claude (Windows fallback when HOME is unset).
  # The .claude-suffix guard matters for a directory-source marketplace (e.g. a shared kit dir): there
  # the plugin lives at <share>/plugins/..., so the strip yields <share> (NOT a .claude dir). Without
  # the guard the hook reads/writes the wrong config dir and FRESH_USER never fires; with it that case
  # falls through to $HOME/.claude. A normal install strips to ~/.claude, so it is unchanged.
  $newDeriv = (@(
    '_STRIP="${HOOK_DIR%%/plugins/*}"'
    'if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then'
    '  CLAUDE_DIR="$CLAUDE_CONFIG_DIR"'
    'elif [ "$HOOK_DIR" != "$_STRIP" ] && [ "$_STRIP" != "${_STRIP%/.claude}" ]; then'
    '  CLAUDE_DIR="$_STRIP"'
    'elif [ -n "${HOME:-}" ]; then'
    '  CLAUDE_DIR="$HOME/.claude"'
    'else'
    '  CLAUDE_DIR="${USERPROFILE:-}/.claude"'
    'fi'
  ) -join "`n")
  foreach ($h in $ShipHooks) {
    $src = Join-Path $ClaudeDir "hooks/$h"
    if (-not (Test-Path $src)) { throw "Allowlisted hook '$h' not found at $src" }
    # Read as UTF-8 (BOM-detected). Get-Content -Raw decoded BOM-less UTF-8 as CP1252, which
    # double-encoded every em-dash/box-rule into mojibake in the shipped banner -- fixed here.
    $c = [System.IO.File]::ReadAllText($src)
    $c = $c.Replace("`r`n", "`n").Replace("`r", "`n")   # force LF so bash never chokes on CR
    $c = $c.Replace($oldDeriv, $newDeriv)   # D1: robustly resolve the data dir (literal replace)
    if ($c -match [regex]::Escape('$HOOK_DIR/..')) { throw "Hook '$h' still resolves CLAUDE_DIR from BASH_SOURCE -- D1 patch did not apply (source line changed?)" }
    Write-NoBom (Join-Path $destRoot $h) $c
  }
  # copy the hand-maintained hooks.json + stamp the plugin-side version marker (B4)
  Copy-Item (Join-Path $RepoRoot "$PluginRel/hooks/hooks.json") (Stage-Path "$PluginRel/hooks/hooks.json") -Force
  # Ship the Git Bash wrapper VERBATIM (no LF conversion -- cmd.exe needs CRLF). hooks.json invokes
  # the .sh hooks through this instead of bare `bash`, so PATH order can't pick the WSL bash stub.
  # It rides in the package, so `claude plugin update` re-ships it intact (no in-place patch to wipe).
  Copy-Item (Join-Path $RepoRoot "$PluginRel/scripts/run-bash-hook.cmd") (Join-Path $destRoot 'run-bash-hook.cmd') -Force
  Write-NoBom (Join-Path $destRoot '.kit-version') $Version
  $Report.Add("hooks: $($ShipHooks -join ', ') (D1-patched) + run-bash-hook.cmd; .kit-version=$Version")
}

function Sync-BootstrapAssets {
  foreach ($a in $BootstrapAssets) {
    $src = Join-Path $ClaudeDir $a.src
    if (-not (Test-Path $src)) { $Report.Add("[WARN] bootstrap asset missing: $($a.src)"); continue }
    Copy-Item $src (Stage-Path "bootstrap/$($a.dst)") -Force
  }
  # carry the bootstrap installer + templates that live in the repo (not derived from ~/.claude)
  foreach ($f in 'install.ps1','settings.template.json','CLAUDE.template.md') {
    $src = Join-Path $RepoRoot "bootstrap/$f"
    if (Test-Path $src) { Copy-Item $src (Stage-Path "bootstrap/$f") -Force }
  }

  # Ship a NEUTRAL theme, not the author's live look. Reset the staged statusline to the
  # 'default' palette with no pinned overrides, and write the matching stock cc-active.json,
  # so a first-time recipient sees stock Claude Code dark (not whatever palette the author runs).
  # /theme then lets them switch + activates the custom theme (settings 'theme' = custom:cc-active).
  $slStage = Stage-Path 'bootstrap/statusline.ps1'
  if (Test-Path $slStage) {
    $sl = [System.IO.File]::ReadAllText($slStage)
    $sl = $sl.Replace("`r`n", "`n").Replace("`r", "`n")
    $sl = [regex]::Replace($sl, '(?m)^\$palette\s*=.*$',      "`$palette = 'default'")
    $sl = [regex]::Replace($sl, '(?m)^\$barOverride\s*=.*$',  "`$barOverride  = ''")
    $sl = [regex]::Replace($sl, '(?m)^\$barPinned\s*=.*$',    "`$barPinned    = `$false")
    $sl = [regex]::Replace($sl, '(?m)^\$baseOverride\s*=.*$', "`$baseOverride = ''")
    $sl = [regex]::Replace($sl, '(?m)^\$basePinned\s*=.*$',   "`$basePinned   = `$false")
    Write-NoBom $slStage $sl
    $Report.Add("statusline sanitized to 'default' palette (overrides cleared)")
  }
  $defaultTheme = ([ordered]@{ name = 'CC Active (default - stock)'; base = 'dark'; overrides = [ordered]@{} } | ConvertTo-Json -Depth 5)
  Write-NoBom (Stage-Path 'bootstrap/themes/cc-active.json') $defaultTheme

  $Report.Add("bootstrap assets synced")
}

function Stamp-Version {
  Write-NoBom (Stage-Path 'VERSION') $Version
  $pj = Stage-Path "$PluginRel/.claude-plugin/plugin.json"
  $srcPj = Join-Path $RepoRoot "$PluginRel/.claude-plugin/plugin.json"
  if (Test-Path $srcPj) {
    $o = Get-Content $srcPj -Raw | ConvertFrom-Json
    if ($o.PSObject.Properties.Name -contains 'version') { $o.version = $Version } else { $o | Add-Member -NotePropertyName version -NotePropertyValue $Version }
    Write-NoBom $pj ((,$o) | ConvertTo-Json -Depth 20)
  }
  # marketplace.json carried as-is
  $mp = Join-Path $RepoRoot ".claude-plugin/marketplace.json"
  if (Test-Path $mp) { Copy-Item $mp (Stage-Path ".claude-plugin/marketplace.json") -Force }
  $Report.Add("version stamped: $Version")
}

function Build-ClaudeTemplate {
  # Deliberately does NOT pull the live CLAUDE.md (it carries the canary/ADHD/personal content).
  # The genericized template is hand-maintained in the repo; we validate it exists + is non-skeletal.
  $tmpl = Stage-Path 'bootstrap/CLAUDE.template.md'
  if (-not (Test-Path $tmpl)) { $Report.Add("[WARN] bootstrap/CLAUDE.template.md missing"); return }
  $len = (Get-Content $tmpl -Raw).Length
  if ($len -lt 400) { $Report.Add("[REVIEW] CLAUDE.template.md looks like a skeleton ($len chars) -- finish genericizing by hand (human-judgement task).") }
}

function Generate-SkillReference {
  # Auto-generate GUIDE's per-skill table from shipped SKILL.md `description` frontmatter (no drift).
  $rows = New-Object System.Collections.Generic.List[string]
  $rows.Add('# Skill reference (auto-generated by build-package.ps1 -- do not hand-edit)')
  $rows.Add('')
  $rows.Add('| Skill | What it does (from its SKILL.md) |')
  $rows.Add('|-------|----------------------------------|')
  foreach ($s in ($ShipSkills | Sort-Object)) {
    if ($ExcludeSkills -contains $s) { continue }
    $md = Stage-Path "$PluginRel/skills/$s/SKILL.md"
    $desc = ''
    if (Test-Path $md) {
      # Read as UTF-8 (BOM-detected). Get-Content -Raw decodes BOM-less UTF-8 as CP1252, which
      # baked mojibake (em-dash -> "a-EUR" garble) into the generated table -- same fix as Sync-Hooks.
      $m = [regex]::Match([System.IO.File]::ReadAllText($md), '(?ms)^description:\s*"?(.*?)"?\s*$')
      if ($m.Success) { $desc = ($m.Groups[1].Value -replace '\s+',' ').Trim() }
      if ($desc.Length -gt 240) { $desc = $desc.Substring(0,237) + '...' }
    }
    $rows.Add("| ``$s`` | $desc |")
  }
  Write-NoBom (Stage-Path 'GUIDE-skills.generated.md') ($rows -join "`n")
  $Report.Add("generated GUIDE-skills.generated.md ($($ShipSkills.Count) skills)")
}

function Sync-Docs {
  foreach ($d in $ShipDocs) {
    $src = Join-Path $RepoRoot $d
    if (Test-Path $src) { Copy-Item $src (Stage-Path $d) -Force } else { $Report.Add("[WARN] doc missing (write it): $d") }
  }
}

function Assert-NoPersonalData {
  $hits = New-Object System.Collections.Generic.List[string]
  Get-ChildItem $Stage -Recurse -File | ForEach-Object {
    $text = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $text) { return }
    foreach ($allow in $LeakAllowList) { $text = $text -replace [regex]::Escape($allow), '' }
    foreach ($pat in $LeakPatterns) {
      $m = [regex]::Matches($text, $pat)
      if ($m.Count -gt 0) { $hits.Add("  $($_.FullName.Substring($Stage.Length)) :: '$pat' x$($m.Count)") }
    }
  }
  if ($hits.Count -gt 0) {
    Write-Host "`n!! Assert-NoPersonalData FAILED -- staged package contains leak markers:" -ForegroundColor Red
    $hits | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw "Build aborted: personal-data markers in stage. NOTHING promoted to the repo. Scrub the source, re-run."
  }
  $Report.Add("Assert-NoPersonalData: clean")
}

function Promote-Stage {
  foreach ($d in @($PluginRel,'bootstrap','.claude-plugin')) {
    $dst = Join-Path $RepoRoot $d
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    $src = Stage-Path $d
    if (Test-Path $src) { Copy-Item $src $dst -Recurse -Force }
  }
  foreach ($f in @($ShipDocs + @('VERSION','GUIDE-skills.generated.md'))) {
    $src = Stage-Path $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $RepoRoot $f) -Force }
  }
  $Report.Add("promoted stage -> repo")
}

function Invoke-Build {
  Write-Host "== build-package v$Version  (stage: $Stage) =="
  if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
  New-Item -ItemType Directory -Path $Stage -Force | Out-Null
  foreach ($d in @("$PluginRel/skills","$PluginRel/commands","$PluginRel/scripts","$PluginRel/hooks",
                   "$PluginRel/.claude-plugin",".claude-plugin","bootstrap/themes","bootstrap/scripts")) {
    New-Item -ItemType Directory -Path (Stage-Path $d) -Force | Out-Null
  }

  Sync-Skills
  Sync-Commands
  Sync-Hooks
  Sync-BootstrapAssets
  Stamp-Version
  Build-ClaudeTemplate
  Generate-SkillReference
  Sync-Docs
  Assert-NoPersonalData     # <- HARD GATE: throws before Promote on any leak
  Promote-Stage
  Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue

  Write-Host "`n-- build summary ---------------------------------------------------"
  $Report | ForEach-Object { Write-Host "  $_" }
  Write-Host "--------------------------------------------------------------------"
  Write-Host "Built v$Version. Review the diff, then: git add -A; git commit; git push."
}

Invoke-Build
