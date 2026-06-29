# Claude Code statusline: glanceable usage indicator.
# Reads the statusline JSON payload on stdin and prints one line:
#   5h: <circle> NN%  wk: <circle> NN%  ctx: <circle> NN%  tok: NNNk
# Circles fill by that metric's own percentage; color flags severity.
# Rate-limit fields are absent until the first API response and only for
# Pro/Max subscribers, so those degrade to "--" when missing.

param(
  [switch]$Preview,   # -Preview prints the palette gallery instead of a status line
  [switch]$Apply      # -Apply regenerates the Claude Code theme file from the active palette + overrides
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$e       = [char]27
$reset   = "$e[0m"
$dim     = "$e[2m"
$magenta = "$e[1;35m"  # repo name tint; matches the session-start banner's repo color
$accent = "$e[38;2;177;185;249m"  # fallback slash-command blue; overridden in normal mode (below) to track the active palette bar

# Five quarter-filled circle glyphs, built from codepoints.
$circles = @(
  [char]0x25CB,  # empty
  [char]0x25D4,  # one quarter
  [char]0x25D1,  # half
  [char]0x25D5,  # three quarter
  [char]0x25CF   # full
)

function Glyph([double]$pct) {
  # Floor to completed quarters: only fill a segment once usage has actually
  # reached it, so the circle never over-states (63% reads as half, not 3/4).
  if     ($pct -lt 25)  { $circles[0] }
  elseif ($pct -lt 50)  { $circles[1] }
  elseif ($pct -lt 75)  { $circles[2] }
  elseif ($pct -lt 100) { $circles[3] }
  else                  { $circles[4] }
}

# --- Color gradient ---------------------------------------------------------
# Pick ONE active ramp here. Each palette is an ordered list of RGB stops; the
# percentage maps continuously across them (Windows Terminal truecolor). All
# ramps run "calm" at low usage to "intense/deep" at high usage, so the low end
# is the relaxed color and the high end carries the warning.
$palette = 'aurora'

# --- Theme layers -----------------------------------------------------------
# A palette is the master selection: it drives the statusline gradient AND, via
# -Apply, the Claude Code input-bar (prompt border) color and base theme. The
# two override slots below let a single layer be customized independently.
# Empty override => that layer follows the palette. A *pinned* override survives
# a palette switch; an unpinned one is cleared the next time /theme <palette>
# runs (palettes reset everything unless pinned or saved as a new palette).
$barOverride  = ''          # explicit prompt-bar hex ('' = derive from palette's mid stop)
$barPinned    = $false      # $true keeps $barOverride across palette switches
$baseOverride = ''          # explicit CC base theme ('' = use the palette's base)
$basePinned   = $false      # $true keeps $baseOverride across palette switches

# Per-palette base theme. Defaults to 'dark' for any palette not listed here;
# all current ramps are tuned for dark backgrounds.
$paletteBases = [ordered]@{}

# Per-palette prompt-bar color. Hand-picked accents that read well on a black
# background; a palette not listed here falls back to its mid-stop hue (PaletteBar).
$paletteBars = [ordered]@{
  'neon'     = '#39ff14'   # neon green
  'classic'  = '#d4a017'   # warm gold (mid stop)
  'punchier' = '#ff073a'   # neon red
  'muted'    = '#c6aa82'   # warm pale brown
  'earthy'   = '#6f4e37'   # coffee brown
}

$palettes = [ordered]@{
  'default' = @(@(177,185,249),@(120,128,210),@(60,70,150))  # reset target: stock CC dark (no overrides). Gradient is the statusline's own decoration, echoing CC's default accent blue.
  'neon'    = @(@(0,255,0),   @(255,240,0), @(255,30,60))    # fluorescent green/yellow/red
  'classic' = @(@(0,200,0),   @(220,200,0), @(220,40,40))    # moderate, muted-bright
  'punchier'= @(@(0,230,40),  @(255,225,0), @(245,20,20))    # saturated, vivid red
  'muted'   = @(@(90,170,90), @(200,180,90),@(195,75,60))    # desaturated pastels, redder top
  'earthy'  = @(@(110,160,70),@(200,160,60),@(170,70,50))    # olive/ochre/brick
  'fire'    = @(@(255,245,140),@(255,140,0), @(190,0,0))     # warm only: yellow->orange->deep red
  'ice'     = @(@(190,255,255),@(0,180,255), @(0,40,170))    # pale cyan -> deep blue
  'ocean'   = @(@(0,210,180), @(0,120,200),  @(20,30,120))   # teal -> navy
  'violet'  = @(@(255,130,210),@(200,0,170), @(90,0,150))    # pink -> magenta -> deep purple
  'viridis' = @(@(253,231,37),@(33,145,140), @(68,1,84))     # yellow -> teal -> deep purple
  'sunset'  = @(@(255,225,120),@(255,90,60), @(110,20,90))   # gold -> coral -> deep plum
  'aurora'  = @(@(180,255,160),@(0,200,180), @(40,20,120))   # pale green -> teal -> indigo
  'plasma'  = @(@(250,230,80),@(230,60,150), @(50,10,110))   # yellow -> magenta -> deep purple
  'forest'  = @(@(200,230,120),@(60,160,80), @(10,50,40))    # lime -> green -> deep evergreen
  'mono'    = @(@(80,80,80),  @(170,170,170),@(245,245,245)) # grayscale (dark->light, ok on dark bg)
}

function RampColor($stops, [double]$pct) {
  # Continuous N-stop interpolation across an explicit list of RGB stops.
  $n = $stops.Count
  $p = [math]::Max(0.0, [math]::Min(100.0, $pct))
  if ($n -eq 1) {
    $a = $stops[0]; $b = $stops[0]; $t = 0.0
  } else {
    $f = ($p / 100.0) * ($n - 1)        # position in stop-index space
    $i = [int][math]::Floor($f)
    if ($i -ge $n - 1) { $i = $n - 2 }  # clamp the top edge so $i+1 is valid
    $t = $f - $i
    $a = $stops[$i]; $b = $stops[$i + 1]
  }
  $r = [int]($a[0] + ($b[0] - $a[0]) * $t)
  $g = [int]($a[1] + ($b[1] - $a[1]) * $t)
  $bl = [int]($a[2] + ($b[2] - $a[2]) * $t)
  "$e[38;2;$r;$g;${bl}m"
}

function SevColor([double]$pct) {
  # Color for the active palette at this percentage.
  RampColor $palettes[$palette] $pct
}

function ToHex($rgb) {
  # [r,g,b] (0-255) -> "#rrggbb".
  '#{0:x2}{1:x2}{2:x2}' -f [int]$rgb[0], [int]$rgb[1], [int]$rgb[2]
}

function HexFg($hex) {
  # "#rrggbb" -> truecolor foreground escape. Used by the preview bar swatch.
  $r = [int]("0x" + $hex.Substring(1,2))
  $g = [int]("0x" + $hex.Substring(3,2))
  $b = [int]("0x" + $hex.Substring(5,2))
  "$e[38;2;$r;$g;${b}m"
}

function Lighten($rgb, [double]$amt) {
  # Blend toward white by $amt (0..1); used for the shimmer companion color.
  @(
    [int]($rgb[0] + (255 - $rgb[0]) * $amt),
    [int]($rgb[1] + (255 - $rgb[1]) * $amt),
    [int]($rgb[2] + (255 - $rgb[2]) * $amt)
  )
}

function MixGray($rgb, [double]$amt) {
  # Blend toward mid-gray (128) by $amt (0..1); desaturates and tames a hue so
  # the 'inactive' secondary text recedes while keeping the palette tint.
  @(
    [int]($rgb[0] + (128 - $rgb[0]) * $amt),
    [int]($rgb[1] + (128 - $rgb[1]) * $amt),
    [int]($rgb[2] + (128 - $rgb[2]) * $amt)
  )
}

function BlendTo($rgb, $target, [double]$amt) {
  # Blend $rgb toward an explicit $target RGB by $amt (0..1). Pulls a palette hue
  # into a restricted range (e.g. warm) while keeping some of its original tint.
  @(
    [int]($rgb[0] + ($target[0] - $rgb[0]) * $amt),
    [int]($rgb[1] + ($target[1] - $rgb[1]) * $amt),
    [int]($rgb[2] + ($target[2] - $rgb[2]) * $amt)
  )
}

function PaletteBar($name) {
  # Hand-picked bar color if the palette has one, else its mid stop (the
  # signature hue of the ramp).
  if ($paletteBars.Contains($name)) { return $paletteBars[$name] }
  $stops = $palettes[$name]
  $mid   = $stops[[int][math]::Floor($stops.Count / 2)]
  ToHex $mid
}

function PaletteBase($name) {
  if ($paletteBases.Contains($name)) { $paletteBases[$name] } else { 'dark' }
}

function PaletteAccents($name) {
  # Palette-derived decorative accents, shared by -Apply and -Preview so the
  # gallery can never drift from what actually gets written. Returns only the
  # non-bar tokens: suggestion = the bright low stop; inactive = a desaturated
  # dim tint of it (+ its shimmer); bashBorder = the intense top stop. The
  # 'claude' brand accent is NOT here -- it tracks the (possibly overridden) bar
  # and is set at each call site.
  $stops  = $palettes[$name]
  $low    = $stops[0]
  $top    = $stops[$stops.Count - 1]
  $inactR = MixGray $low 0.55
  [ordered]@{
    suggestion      = ToHex $low
    inactive        = ToHex $inactR
    inactiveShimmer = ToHex (Lighten $inactR 0.25)
    bashBorder      = ToHex $top
  }
}

function PaletteModes($name) {
  # Palette-derived mode/dialog accents, shared by -Apply and -Preview so the gallery
  # can never drift from what gets written. planMode = top lightened 40% (deep top hue
  # kept legible as a border); autoAccept = the bright low stop (accept-edits is the
  # mode actually toggled, so it gets the most visible color); permission = top lightened
  # 25% (+shimmer), a deeper alert hue distinct from planMode; warning = the palette
  # mid (signature) hue pulled toward a warm amber anchor by $warmAmt, so the AUTO
  # mode border lands in a restricted warm/caution range while still carrying the
  # palette's tint (greener-gold on cool palettes, true orange on warm ones). CC
  # shares this token with warning/caution messages. Raise $warmAmt toward 1.0 for a
  # warmer, more uniform amber; lower it for more palette character. shimmer = +25%.
  # subtle = the bar hue desaturated toward gray then darkened, so faint borders carry
  # the tint while de-emphasized text stays legible. fastMode/ide/selectionBg unset.
  $stops = $palettes[$name]
  $low = $stops[0]; $mid = $stops[1]; $top = $stops[$stops.Count - 1]
  $subBase = MixGray $mid 0.45
  $warmAnchor = @(255,179,0)            # amber target for the warning band
  $warmAmt    = 0.75                    # how far the warning hue is pulled toward amber
  $warn       = BlendTo $mid $warmAnchor $warmAmt
  [ordered]@{
    planMode          = ToHex (Lighten $top 0.40)
    autoAccept        = ToHex $low
    warning           = ToHex $warn
    warningShimmer    = ToHex (Lighten $warn 0.25)
    permission        = ToHex (Lighten $top 0.25)
    permissionShimmer = ToHex (Lighten $top 0.45)
    subtle            = ToHex @([int]($subBase[0]*0.6), [int]($subBase[1]*0.6), [int]($subBase[2]*0.6))
  }
}

function EffectiveBar  { if ($barOverride)  { $barOverride }  else { PaletteBar  $palette } }
function EffectiveBase { if ($baseOverride) { $baseOverride } else { PaletteBase $palette } }

# -Apply mode: regenerate ~/.claude/themes/cc-active.json from the active palette
# plus any overrides, then exit. settings.json points "theme" at "custom:cc-active"
# permanently, so this file is the only thing that changes on a theme switch.
if ($Apply) {
  $dir = Join-Path $env:USERPROFILE '.claude\themes'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $themePath = Join-Path $dir 'cc-active.json'
  # Write BOM-free UTF-8: Windows PowerShell 5.1's Set-Content -Encoding utf8
  # prepends a BOM, which makes Claude Code's JSON parser reject the theme file.
  $enc = New-Object System.Text.UTF8Encoding($false)

  # 'default' is a reset target: stock Claude Code dark with NO overrides. It
  # deliberately ignores any bar/base override and renders identically to the
  # built-in 'dark' preset (the look before any theme customization).
  if ($palette -eq 'default') {
    $json = ([ordered]@{ name = 'CC Active (default - stock)'; base = 'dark'; overrides = [ordered]@{} } | ConvertTo-Json -Depth 5)
    [System.IO.File]::WriteAllText($themePath, $json, $enc)
    Write-Host "Applied theme: 'default' (stock Claude Code dark, no overrides) -> themes\cc-active.json"
    exit 0
  }

  $bar     = EffectiveBar
  $base    = EffectiveBase
  # Shimmer: lighten the bar hex by 25% toward white.
  $b       = [int]("0x" + $bar.Substring(1,2)), [int]("0x" + $bar.Substring(3,2)), [int]("0x" + $bar.Substring(5,2))
  $shimmer = ToHex (Lighten $b 0.25)
  # Decorative accent tokens coordinated to the palette (derived by PaletteAccents,
  # shared with -Preview). Only non-semantic tokens are recolored, so
  # error/success/warning/diff keep their meaning. claude (the spinner/brand
  # accent) tracks the bar.
  $acc = PaletteAccents $palette
  # Usage bars (/usage) track the input bar: fill = the bar color, empty = a
  # darkened version of it (40% brightness) so the unfilled track is the same hue
  # but recedes. Keeps the /usage meter visually tied to the prompt border.
  $rlEmpty = ToHex @([int]($b[0]*0.4), [int]($b[1]*0.4), [int]($b[2]*0.4))

  # Palette-derived mode/accent tokens (Scheme A: each tracks a palette stop).
  # planMode  = top stop lightened 40% so the deep top hue stays legible as a border.
  # autoAccept= low (bright) stop -- accept-edits is the mode actually toggled, so it
  #             gets the most visible color. fastMode/ide are intentionally NOT set
  #             (unused; they fall through to the base preset).
  # Palette-derived mode/dialog accents (shared with -Preview via PaletteModes so the
  # gallery never drifts from what is written here).
  $mode = PaletteModes $palette

  $theme   = [ordered]@{
    name      = "CC Active ($palette)"
    base      = $base
    overrides = [ordered]@{
      promptBorder        = $bar
      promptBorderShimmer = $shimmer
      claude              = $bar
      claudeShimmer       = $shimmer
      suggestion          = $acc.suggestion
      inactive            = $acc.inactive
      inactiveShimmer     = $acc.inactiveShimmer
      bashBorder          = $acc.bashBorder
      rate_limit_fill     = $bar
      rate_limit_empty    = $rlEmpty
      planMode            = $mode.planMode
      autoAccept          = $mode.autoAccept
      warning             = $mode.warning
      warningShimmer      = $mode.warningShimmer
      permission          = $mode.permission
      permissionShimmer   = $mode.permissionShimmer
      subtle              = $mode.subtle
    }
  }
  $json = $theme | ConvertTo-Json -Depth 5
  [System.IO.File]::WriteAllText($themePath, $json, $enc)
  Write-Host "Applied theme: palette '$palette', bar $bar, base $base (accents: claude=$bar suggestion=$($acc.suggestion) inactive=$($acc.inactive) bashBorder=$($acc.bashBorder)) -> themes\cc-active.json"
  exit 0
}

function Segment($label, $value) {
  if ($null -eq $value) {
    return "$dim${label}: $($circles[0]) --%$reset"
  }
  $pct = [math]::Round([double]$value)
  $col = SevColor $pct
  $g   = Glyph $pct
  return "$col${label}: $g $pct%$reset"
}

# -Preview mode: print every palette as a 0->100% bar plus sampled circles,
# mark the active one, then exit. The /theme command calls this to show options.
if ($Preview) {
  Write-Host ""
  $blk = [string][char]0x2588
  foreach ($name in $palettes.Keys) {
    $stops = $palettes[$name]
    $bar = ""
    for ($i = 0; $i -lt 44; $i++) { $p = $i * 100.0 / 43; $bar += (RampColor $stops $p) + [char]0x2588 }
    $samp = ""
    foreach ($p in 10, 40, 60, 80, 100) { $samp += (RampColor $stops $p) + (Glyph $p) + " " }
    $mark = if ($name -eq $palette) { "*" } else { " " }
    # 'default' applies no overrides, so it has no bar/accent colors to swatch.
    if ($name -eq 'default') {
      Write-Host ("{0} {1,-9}{2}{3}  {4}{3} {5}stock CC dark - clears all overrides{3}" -f $mark, $name, $bar, $reset, $samp, $dim)
      continue
    }
    # Bar-color swatch: the prompt-border color this palette maps to (also the
    # 'claude' spinner/brand accent). Then the palette-derived accent swatches,
    # each tagged so it is clear which token it represents.
    $barColor = PaletteBar $name
    $barSw = (HexFg $barColor) + ($blk * 3) + $reset
    $acc = PaletteAccents $name
    $mode = PaletteModes $name
    $accSw = (@(
      @('sug', $acc.suggestion),
      @('ina', $acc.inactive),
      @('bsh', $acc.bashBorder),
      @('pln', $mode.planMode),
      @('aut', $mode.autoAccept),
      @('wrn', $mode.warning),
      @('prm', $mode.permission),
      @('sub', $mode.subtle)
    ) | ForEach-Object { "$dim$($_[0])$reset" + (HexFg $_[1]) + $blk + $reset }) -join " "
    Write-Host ("{0} {1,-9}{2}{3}  {4}{3} {5} {6}   {7}" -f $mark, $name, $bar, $reset, $samp, $barSw, $barColor, $accSw)
  }
  Write-Host ""
  $barNote  = if ($barOverride)  { "$(EffectiveBar) (override, pinned=$barPinned)" }   else { "$(EffectiveBar) (from palette)" }
  $baseNote = if ($baseOverride) { "$(EffectiveBase) (override, pinned=$basePinned)" } else { "$(EffectiveBase) (from palette)" }
  Write-Host "  * = active ($palette)   |   gradient 0->100%, circles at 10/40/60/80/100%, then bar swatch + hex"
  Write-Host "  accent swatches after the hex (the CC theme tokens each palette sets):"
  Write-Host "    bar swatch = promptBorder + claude (spinner/brand)   sug = suggestion (autocomplete)   ina = inactive (hints/timestamps)   bsh = bashBorder (! shell mode)"
  Write-Host "    pln = planMode (plan border)   aut = autoAccept (accept-edits border)   wrn = warning (auto mode border + caution msgs)   prm = permission (dialog border)   sub = subtle (faint borders/text)"
  Write-Host "  prompt bar: $barNote     base theme: $baseNote"
  exit 0
}

# Normal mode: read the statusline JSON payload from stdin.
$raw = [Console]::In.ReadToEnd()
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

# Slash-command accent tracks the active palette's bar color, so /usage and /theme
# match the prompt border / theme instead of the hardcoded default blue. EffectiveBar
# honors a pinned bar override too. 'default' palette falls back to its mid stop.
if ($palette -ne 'default') { $accent = HexFg (EffectiveBar) }

$fiveHr = $j.rate_limits.five_hour.used_percentage
$week   = $j.rate_limits.seven_day.used_percentage
$ctx    = $j.context_window.used_percentage
$inTok  = $j.context_window.total_input_tokens
$outTok = $j.context_window.total_output_tokens

# Persist the latest rate-limit percentages so the scheduled /eod launcher
# (run-eod.ps1 Guard 0) can pre-flight skip when usage is high. This is the ONLY
# place the usage signal exists -- Claude Code pipes it here, nowhere on disk.
# Best-effort: a write failure must never break the statusline, hence the try/catch.
if (($null -ne $fiveHr) -or ($null -ne $week)) {
  try {
    $rlState = Join-Path $env:USERPROFILE ".claude\.rate-limit-state.json"
    $rlJson  = '{{"five_hour":{0},"seven_day":{1},"ts":"{2}"}}' -f `
      ([int]$fiveHr), ([int]$week), (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    Set-Content -Path $rlState -Value $rlJson -Encoding ASCII -ErrorAction Stop
  } catch {}
}

# Current repo: git top-level basename of the session dir (matches the semantics
# the session-start banner used before this moved here). "none" outside a repo.
# Costs one git fork per statusline render — accepted to keep the repo glanceable.
$repoName = "none"
$repoDir  = $j.workspace.current_dir
if (-not $repoDir) { $repoDir = $j.cwd }
if ($repoDir) {
  $top = git -C "$repoDir" rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -eq 0 -and $top) { $repoName = Split-Path -Leaf $top }
}
$parts = @("current repo: $magenta$repoName$reset")
$parts += "---"

$parts += (
  (Segment "5h"  $fiveHr),
  (Segment "wk"  $week),
  (Segment "ctx" $ctx)
)

# Plan-neutral session weight: total tokens moved this session.
if (($null -ne $inTok) -or ($null -ne $outTok)) {
  $tok = [double]$inTok + [double]$outTok
  if ($tok -ge 1000) {
    $tokStr = "{0:N0}k" -f [math]::Round($tok / 1000)
  } else {
    $tokStr = "{0:N0}" -f $tok
  }
  $parts += "${dim}tok: $tokStr$reset"
}


# Trailing pointers: /usage opens the built-in usage breakdown (session cost,
# plan bars, token attribution); /theme previews and switches the color palette.
# These sit last, after the token count. True right-edge alignment is not
# possible: Claude Code does not export COLUMNS to the statusline command and the
# payload carries no width field, so there is no reliable width to pad against.
# /usage and /theme are tinted with an accent blue to read as slash commands
# (Claude Code does not auto-color statusline text); the dot separator stays dim.
$parts += "---"
$parts += $accent + "/usage " + [char]0x00B7 + " /theme" + $reset

$line = $parts -join "  "

[Console]::Out.Write($line)
