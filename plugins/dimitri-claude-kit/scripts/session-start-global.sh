#!/bin/bash
set -euo pipefail

# Global session-start hook â€” portable, no project-specific logic.
# Emits JSON: systemMessage (thread table, shown in chat at startup) +
# hookSpecificOutput.additionalContext (full context for Claude).

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
NOTE_DIR="$CLAUDE_DIR/session-notes"
THREADS_INDEX="$CLAUDE_DIR/threads/INDEX.md"

# First-session-of-day gate. Cheap: one date + one small file read. If the last
# orientation date differs from today, flag this session so the additionalContext
# can instruct the pointed `morning` brief. The marker is written by the `morning`
# skill (not here), so an ignored brief re-fires on the next session.
_now=$(date '+%Y-%m-%d %s'); TODAY="${_now% *}"; TODAY_EPOCH="${_now#* }"
ORIENT_MARKER="$CLAUDE_DIR/.last-orientation"
FIRST_SESSION_TODAY=0
if [ ! -f "$ORIENT_MARKER" ] || [ "$(tr -d '[:space:]' < "$ORIENT_MARKER" 2>/dev/null)" != "$TODAY" ]; then
  FIRST_SESSION_TODAY=1
fi

# Morning recap source. We surface the most recent EOD synthesis as a recap above the
# thread board on EVERY session (not just the first of the day), regardless of how old it
# is â€” EOD_RECAP_DATE is parsed whenever eod-latest.md exists and the block renders if it
# is non-empty. RECAP_IS_FRESH=1 only when that EOD is dated yesterday; it no longer gates
# the recap banner, but the first-session recovery path and marker write below still use it
# to decide whether to nudge a /eod regeneration.
YESTERDAY="$(date -d 'yesterday' +%Y-%m-%d 2>/dev/null || true)"
EOD_FILE="$NOTE_DIR/eod-latest.md"
EOD_RECAP_DATE=""
RECAP_PROJECTS=""
RECAP_NEXT=""
RECAP_IS_FRESH=0
LF=$'\n'
if [ -f "$EOD_FILE" ]; then
  # Single awk pass over the EOD file: recap date + first 3 "Projects touched"
  # bullets + first 3 "Tomorrow's priorities". Was three forks (a grep|grep|head
  # date parse here plus two awks in the recap block); now one.
  while IFS=$'\t' read -r _kind _val; do
    case "$_kind" in
      date) EOD_RECAP_DATE="$_val" ;;
      proj) RECAP_PROJECTS="${RECAP_PROJECTS:+$RECAP_PROJECTS$LF}$_val" ;;
      next) RECAP_NEXT="${RECAP_NEXT:+$RECAP_NEXT$LF}$_val" ;;
    esac
  done < <(awk '
    /^# EOD/ && !dd { if (match($0,/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) { print "date\t" substr($0,RSTART,RLENGTH); dd=1 } }
    /^## Projects touched/ { p=1; n=0; next }
    /^## Tomorrow.s priorities/ { n=1; p=0; next }
    /^## / { p=0; n=0 }
    p && /^- / && pc<3 { print "proj\t" $0; pc++ }
    n && /^[0-9]+\./ && nc<3 { print "next\t" $0; nc++ }
  ' "$EOD_FILE")
  if [ "$FIRST_SESSION_TODAY" = "1" ] && [ -n "$EOD_RECAP_DATE" ] && [ -n "$YESTERDAY" ] && [ "$EOD_RECAP_DATE" = "$YESTERDAY" ]; then
    RECAP_IS_FRESH=1
  fi
fi

FULL_CONTENT=""
BANNER_CONTENT=""

# De-dupe with a project-level session-start hook. If the current project ships its own
# .claude/hooks/session-start.sh that already emits the git "Session Context" and/or the
# todos locally, suppress those two sections here so they are not injected twice. Project
# hooks emit the git block only in LOCAL sessions, so this is skipped under remote.
PROJECT_EMITS_GIT=0
PROJECT_EMITS_TODOS=0
PROJECT_HOOK="$PROJECT_DIR/.claude/hooks/session-start.sh"
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ] && [ -f "$PROJECT_HOOK" ]; then
  if grep -q "Session Context" "$PROJECT_HOOK" 2>/dev/null; then PROJECT_EMITS_GIT=1; fi
  if grep -q "todo.md" "$PROJECT_HOOK" 2>/dev/null; then PROJECT_EMITS_TODOS=1; fi
fi

# JSON-escape a string â€” no external tools required
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\033'/\\u001b}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Trim leading/trailing whitespace using builtins only (no subshell/fork).
# Result is returned in $REPLY -- avoids a command-substitution fork per call.
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  REPLY="$s"
}

# Word-wrap $1 to content width $2 with a hanging indent: the first line is
# prefixed with $3, wrapped continuation lines with $4. Result returned in $REPLY
# (lines joined by $NL). Globbing is disabled around the split so EOD markdown
# (**bold**, [tags]) is treated as literal words, not filename patterns. Width is
# measured on the plain text only; the prefixes may carry ANSI codes (zero-width).
wrap_indent() {
  local text="$1" width="$2" p1="$3" pc="$4"
  local out="" line="" word first=1
  set -f
  for word in $text; do
    if [ -z "$line" ]; then
      line="$word"
    elif [ $(( ${#line} + 1 + ${#word} )) -le "$width" ]; then
      line="$line $word"
    else
      if [ "$first" = 1 ]; then out="${p1}${line}"; first=0
      else out="${out}${NL}${pc}${line}"; fi
      line="$word"
    fi
  done
  set +f
  if [ -n "$line" ]; then
    if [ "$first" = 1 ]; then out="${p1}${line}"
    else out="${out}${NL}${pc}${line}"; fi
  fi
  REPLY="$out"
}

# Clip $1 to at most $2 characters on a word boundary, appending an ellipsis when
# truncated. Result in $REPLY. Used by the recap to keep each Did/Next line on a
# single row (no wrap). Plain text only -- never pass ANSI-coded strings in.
clip_line() {
  local s="$1" w="$2"
  if [ "${#s}" -gt "$w" ]; then
    s="${s:0:$w}"; s="${s% *}â€¦"
  fi
  REPLY="$s"
}

# Detect the repo ONCE (was a separate `git rev-parse` here and again for
# SESSION_REPO below â€” two forks collapsed into one).
IS_REPO=0
if git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then IS_REPO=1; fi

# Git context (additionalContext only â€” not shown in banner).
# Skipped when a project session-start hook already emits it (see PROJECT_EMITS_GIT).
if [ "$PROJECT_EMITS_GIT" != "1" ] && [ "$IS_REPO" = "1" ]; then
  BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  COMMIT_COUNT=$(git -C "$PROJECT_DIR" log --oneline -8 2>/dev/null | wc -l | tr -d ' ')
  FULL_CONTENT="## Session Context
Branch: $BRANCH

### Recent commits
$(git -C "$PROJECT_DIR" log --oneline -8 2>/dev/null)

### Working tree
$(git -C "$PROJECT_DIR" status --short 2>/dev/null)

## Instruction
Begin your first reply with exactly one line acknowledging this context, e.g.:
\"Session loaded: branch $BRANCH, $COMMIT_COUNT recent commits.\"
Keep it to one line -- no extra commentary.
"
fi

# Active-thread dashboard
ACTIVE_ROWS=""
if [ -f "$THREADS_INDEX" ]; then
  ACTIVE_ROWS=$(awk '/^## Active/{f=1;next} /^## /{f=0} f && /^[|] *\[\[/' "$THREADS_INDEX" || true)
fi

if [ -n "$ACTIVE_ROWS" ]; then
  # ANSI codes (actual escape sequences, not literals)
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  MAGENTA=$'\033[1;35m'
  YELLOW=$'\033[1;33m'
  CYAN=$'\033[36m'
  # Slash-command accent blue â€” matches /usage and /theme in statusline.ps1
  ACCENT=$'\033[38;2;177;185;249m'
  # Dimmer accent + dim text for inline command hints (one level down from ACCENT);
  # used for the catchup pointers and the "expand" keyword on the overflow line.
  ACCENT_DIM=$'\033[38;2;124;130;174m'
  TEXT_DIM=$'\033[38;2;90;90;90m'
  RESET=$'\033[0m'
  NL=$'\n'

  # Morning recap block (every session): condensed projects + top pickup from the
  # most recent EOD, rendered above the thread board. Renders whenever an EOD with a
  # parseable date exists, regardless of age. The /goals nudge is appended to the
  # banner separately (where the old warning sat).
  # Morning recap "B1": action-first. Top 3 priorities (Next) lead, then the top 3
  # projects touched (Did) as one tight clipped line each. Action leads because this
  # banner renders on EVERY session, not just the cold first-of-day, so the warm
  # case wants the next steps up top; the Did block sits below for genuine recall.
  RECAP_BLOCK=""
  if [ -n "$EOD_RECAP_DATE" ]; then
    # RECAP_PROJECTS / RECAP_NEXT were parsed in the single EOD awk pass above.

    # Header gets a days-ago suffix so staleness is obvious at a glance.
    _days=""
    if _e=$(date -d "$EOD_RECAP_DATE" +%s 2>/dev/null) && _t="$TODAY_EPOCH"; then
      _d=$(( (_t - _e) / 86400 ))
      if   [ "$_d" -le 0 ]; then _days=" (today)"
      elif [ "$_d" -eq 1 ]; then _days=" (yesterday)"
      else _days=" (${_d} days ago)"; fi
    fi

    GUT="        "            # 8-col continuation indent, matches "  Next  "
    _cw="${RECAP_COLS:-92}"   # content target width (override via RECAP_COLS)

    RECAP_BLOCK="â”€ ${BOLD}Last recap Â· ${EOD_RECAP_DATE}${_days} â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€${RESET}${NL}${NL}"

    # Did: pull the bold thread name and the detail after the em-dash; shorten the
    # name and clip the detail so each project stays on one line. Rendered first
    # (above Next) so the recall context precedes the action items.
    if [ -n "$RECAP_PROJECTS" ]; then
      _i=0
      while IFS= read -r _ln; do
        [ -z "$_ln" ] && continue
        _i=$((_i + 1))
        _name="${_ln#*\*\*}"; _name="${_name%%\*\**}"
        _name="${_name#dimitri-}"
        clip_line "$_name" 28; _name="$REPLY"
        _det="${_ln#*â€” }"
        [ "$_det" = "$_ln" ] && _det="${_ln#- }"
        trim "$_det"; _det="$REPLY"
        clip_line "$_det" "$((_cw - ${#_name} - 11))"; _det="$REPLY"
        if [ "$_i" = 1 ]; then _pre="  ${BOLD}Did ${RESET}  "; else _pre="$GUT"; fi
        RECAP_BLOCK="${RECAP_BLOCK}${_pre}${_name} â€” ${_det}${NL}"
      done <<< "$RECAP_PROJECTS"
      RECAP_BLOCK="${RECAP_BLOCK}${NL}"
    fi

    # Next: strip the leading "N." and the trailing [thread] tag, clip the text to
    # one line, re-append the tag dim. Tag's noisiest prefix (dimitri-) trimmed.
    # Number + text render normal weight (unbolded, undimmed), matching the Did lines.
    if [ -n "$RECAP_NEXT" ]; then
      _i=0
      while IFS= read -r _ln; do
        [ -z "$_ln" ] && continue
        _i=$((_i + 1))
        _txt="${_ln#*. }"
        trim "$_txt"; _txt="$REPLY"
        # EOD priority lines end "... [thread]." -- drop the trailing period so the
        # closing-bracket test fires, then lift the tag out.
        _txt="${_txt%.}"
        _tag=""
        case "$_txt" in
          *\]) _tag="${_txt##*[}"; _tag="${_tag%]}"; _txt="${_txt%[*}" ;;
        esac
        _tag="${_tag#dimitri-}"
        trim "$_txt"; _txt="$REPLY"
        clip_line "$_txt" "$((_cw - 12))"; _txt="$REPLY"
        if [ "$_i" = 1 ]; then _pre="  ${BOLD}Next${RESET}  "; else _pre="$GUT"; fi
        if [ -n "$_tag" ]; then
          RECAP_BLOCK="${RECAP_BLOCK}${_pre}${_i}. ${_txt} ${TEXT_DIM}[${_tag}]${RESET}${NL}"
        else
          RECAP_BLOCK="${RECAP_BLOCK}${_pre}${_i}. ${_txt}${NL}"
        fi
      done <<< "$RECAP_NEXT"
    fi

    RECAP_BLOCK="${RECAP_BLOCK}${NL}"
  fi

  # Build ANSI banner (for systemMessage / terminal display).
  # IMPORTANT: systemMessage must LEAD with a printable character. The harness trims leading
  # whitespace and then drops a banner whose remaining text begins with an ANSI escape, so a
  # board starting with "${NL}${NL}${DIM}..." rendered as nothing on cold `startup` (it survived
  # `clear`/`resume`, which were more lenient). The repo moved to the statusline, so both the
  # recap header and the Active-threads header now lead with a plain "â”€ " rule so whichever
  # comes first (recap is optional) still satisfies the printable-lead rule.
  ANSI_BANNER="${RECAP_BLOCK}"
  ANSI_BANNER="${ANSI_BANNER}â”€ ${BOLD}Active threads â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€${RESET}${NL}"
  ANSI_BANNER="${ANSI_BANNER}  ${DIM}[${RESET}${YELLOW}High${RESET}${DIM}|${RESET}${CYAN}Mid${RESET}${DIM}|Low] | thread-name | topic | repo | date${RESET}${NL}${NL}"

  mapfile -t _rows_arr <<< "$ACTIVE_ROWS"
  TOTAL_ROWS=${#_rows_arr[@]}

  # Pre-parse EVERY thread file in a SINGLE awk pass (previously one awk fork
  # per thread â€” the dominant startup cost on Windows, ~90ms/fork). Emits
  # tab-separated records "<slug>\t(topic|next)\t<value>"; FNR==1 resets the
  # per-file state and derives the slug from the filename. Results land in two
  # associative arrays the main loop reads instead of forking awk per thread.
  declare -A TOPIC_MAP NEXT_MAP
  _files=()
  for _r in "${_rows_arr[@]}"; do
    IFS='|' read -r _ _s _ <<< "$_r"
    trim "$_s"; _s="$REPLY"
    _s="${_s//\[/}"; _s="${_s//\]/}"
    _f="$CLAUDE_DIR/threads/active/${_s}.md"
    [ -f "$_f" ] && _files+=("$_f")
  done
  if [ ${#_files[@]} -gt 0 ]; then
    while IFS=$'\t' read -r _k _kind _val; do
      if [ "$_kind" = "topic" ]; then
        TOPIC_MAP["$_k"]="$_val"
      else
        NEXT_MAP["$_k"]="${NEXT_MAP[$_k]:+${NEXT_MAP[$_k]}$'\n'}$_val"
      fi
    done < <(awk '
      FNR==1 { fn=FILENAME; sub(/.*\//,"",fn); sub(/\.md$/,"",fn); t=0; n=0; c=0 }
      /^topic:/ && !t { v=$0; sub(/^topic:[[:space:]]*/,"",v); print fn "\ttopic\t" v; t=1 }
      /^## Next/ { n=1; next }
      /^## / { n=0 }
      n && /^- \[/ && c<3 { print fn "\tnext\t" $0; c++ }
    ' "${_files[@]}")
  fi

  # Single pass over all threads: builds the banner (top 6) AND the
  # additionalContext "next items" (all threads), reading the pre-parsed
  # TOPIC_MAP / NEXT_MAP instead of forking awk per thread.
  NEXT_SECTION=""
  THREAD_ROWS=""
  OVERFLOW_LINE=""
  ROW_NUM=0
  while IFS= read -r row; do
    ROW_NUM=$((ROW_NUM + 1))
    # Parse pipe-delimited columns with builtins only (no per-field subshells):
    # | [[slug]] | project | pri | last | where |
    IFS='|' read -r _ slug project pri last where _ <<< "$row"
    trim "$slug";    slug="$REPLY"
    trim "$project"; project="$REPLY"
    trim "$pri";     pri="$REPLY"
    trim "$last";    last="$REPLY"
    trim "$where";   where="$REPLY"

    # Strip [[ ]] wrappers, then the YYYY-MM- date prefix, from the slug
    slug="${slug//\[/}"; slug="${slug//\]/}"
    short_slug="${slug#[0-9][0-9][0-9][0-9]-[0-9][0-9]-}"

    # Topic + first 3 "## Next" items, looked up from the single-pass awk
    # results (TOPIC_MAP / NEXT_MAP) built above. Empty topic falls back to "â€”".
    topic="â€”"
    [ -n "${TOPIC_MAP[$slug]:-}" ] && topic="${TOPIC_MAP[$slug]}"
    next_items="${NEXT_MAP[$slug]:-}"

    # Numbered briefing-table row (additionalContext): prepend a # column to the
    # raw INDEX row by inserting it after the leading pipe.
    THREAD_ROWS="${THREAD_ROWS}| ${ROW_NUM} | ${row#| }
"

    # Banner: top 5 threads, then a single overflow line
    if [ "$ROW_NUM" -le 5 ]; then
      # Truncate "where I left off" to 120 chars
      if [ ${#where} -gt 120 ]; then
        where="${where:0:120}..."
      fi
      # Priority label + color
      if [ "$pri" = "high" ]; then
        pri_label="${YELLOW}[High]${RESET}"
      elif [ "$pri" = "low" ]; then
        pri_label="${DIM}[Low]${RESET}"
      else
        pri_label="${CYAN}[Mid]${RESET}"
      fi
      ANSI_BANNER="${ANSI_BANNER}  ${BOLD}${ROW_NUM}.${RESET} ${pri_label} | ${MAGENTA}${short_slug}${RESET} | ${DIM}${topic} | ${project} | ${last}${RESET}${NL}"
      ANSI_BANNER="${ANSI_BANNER}         ${where}${NL}${NL}"
    elif [ "$ROW_NUM" -eq 6 ]; then
      REMAINING=$((TOTAL_ROWS - 5))
      # Tint "expand" the same accent-blue as the catchup command hints. Reset
      # first so it does NOT inherit the surrounding DIM attribute (that bleed is
      # what made it render off-blue); restore DIM for the trailing prose.
      OVERFLOW_LINE="... $REMAINING more thread(s) â€” type ${RESET}${ACCENT_DIM}expand${RESET}${DIM} to see all"
    fi

    # Open next items per thread (additionalContext only) â€” all threads
    if [ -n "$next_items" ]; then
      NEXT_SECTION="$NEXT_SECTION

**$slug**
$next_items"
    fi
  done <<< "$ACTIVE_ROWS"

  # Catchup pointers: command names tinted accent-blue (matching /usage and
  # /theme in the statusline), prose left dim. ACCENT_DIM/TEXT_DIM are defined in
  # the ANSI block above. Sits on the overflow line.
  CMD_CATCHUP="${ACCENT_DIM}/catchup${RESET}${TEXT_DIM} <slug>${RESET} ${DIM}-${RESET} ${TEXT_DIM}see more on one thread${RESET}"
  CMD_CATCHUPALL="${ACCENT_DIM}/catchupall${RESET} ${DIM}-${RESET} ${TEXT_DIM}see more on many/all threads${RESET}"
  CMDS="${CMD_CATCHUP} ${DIM}Â·${RESET} ${CMD_CATCHUPALL}"
  if [ -n "$OVERFLOW_LINE" ]; then
    ANSI_BANNER="${ANSI_BANNER}  ${DIM}${OVERFLOW_LINE}${RESET} ${DIM}---${RESET} ${CMDS}${NL}"
  else
    ANSI_BANNER="${ANSI_BANNER}  ${CMDS}${NL}"
  fi

  BANNER_CONTENT="$ANSI_BANNER"

  # Markdown table for Claude's additionalContext (briefing; unchanged)
  THREAD_TABLE="### Active threads
| # | Thread | Project | Prio | Last | Where I left off |
|---|---|---|---|---|---|
${THREAD_ROWS%$'\n'}

_Drill into one with \`/catchup <slug>\` (or \`/catchup <n>\`), or see all with \`/catchupall\`._"

  # The `expand` keyword is handled deterministically by the UserPromptSubmit
  # hook (hooks/expand-prompt.sh), which renders this overview table directly to
  # the user. It is intentionally NOT injected here: doing so pushed this
  # SessionStart additionalContext past the harness inline limit, so the whole
  # payload was persisted to a file and the print-the-table instruction landed
  # past the preview window â€” the model never saw it and `expand` did nothing.
  FULL_CONTENT="$FULL_CONTENT
$THREAD_TABLE
"

  if [ -n "$NEXT_SECTION" ]; then
    FULL_CONTENT="$FULL_CONTENT
### Open next items
$NEXT_SECTION
"
  fi
else
  EOD_FILE="$NOTE_DIR/eod-latest.md"
  if [ -f "$EOD_FILE" ]; then
    FULL_CONTENT="$FULL_CONTENT
### EOD context (from last session)
$(cat "$EOD_FILE")
"
  fi
fi

# Project todos (additionalContext only). Skipped when the project hook already emits them.
TODO="$PROJECT_DIR/.claude/todo.md"
if [ "$PROJECT_EMITS_TODOS" != "1" ] && [ -f "$TODO" ] && [ -s "$TODO" ]; then
  FULL_CONTENT="$FULL_CONTENT
### Open todos
$(cat "$TODO")
"
fi

# First session of the day. Normal path: the recap banner above is rendered by this
# hook and the marker is claimed below, so no skill needs to run. Recovery path (no
# EOD dated yesterday): instruct a /eod regeneration, then a /goals nudge.
if [ "$FIRST_SESSION_TODAY" = "1" ] && [ "$RECAP_IS_FRESH" != "1" ]; then
  FULL_CONTENT="$FULL_CONTENT
## First session today â€” no recap from yesterday (${YESTERDAY})
There is no EOD synthesis dated ${YESTERDAY}. Before addressing the user's first message, run the
\`eod\` skill for ${YESTERDAY} to generate yesterday's recap and check for uncaptured sessions, then
summarize it in one short paragraph and remind the user to run \`/goals\` to set today's goals and
plan. After the recap is shown, write \`${TODAY}\` to \`.last-orientation\` (UTF-8, no BOM) so this
does not re-fire this session.
"
fi

# First-session call to action. The recap above shows where you left off; the day's
# plan is yours to set, so nudge /goals (replaces the old morning-brief warning).
# Appending to BANNER_CONTENT also forces the systemMessage branch below even with no
# threads, so the nudge still shows on a thread-less first session.
if [ "$FIRST_SESSION_TODAY" = "1" ]; then
  _W_RESET=$'\033[0m'
  _W_ACCENT=$'\033[38;2;177;185;249m'
  _W_DIM=$'\033[2m'
  _W_NL=$'\n'
  BANNER_CONTENT="${BANNER_CONTENT}${_W_NL}  ${_W_ACCENT}â–¶ Run /goals${_W_RESET}${_W_DIM} to set today's goals and plan for the day${_W_RESET}${_W_NL}"
fi

# Normal-path marker write: the recap banner was rendered by this hook directly (no
# skill needed), so claim today's orientation here. The recovery path leaves the marker
# untouched so an un-run /eod re-fires next session. printf writes no BOM (the hook's
# bash reader requires that).
if [ "$FIRST_SESSION_TODAY" = "1" ] && [ "$RECAP_IS_FRESH" = "1" ]; then
  printf '%s' "$TODAY" > "$ORIENT_MARKER"
fi

# Emit JSON â€” systemMessage shows the thread table in chat at session start;
# additionalContext injects the full briefing into Claude's context.
ESCAPED_FULL=$(json_escape "$FULL_CONTENT")
if [ -n "$BANNER_CONTENT" ]; then
  ESCAPED_BANNER=$(json_escape "$BANNER_CONTENT")
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "$ESCAPED_BANNER" "$ESCAPED_FULL"
else
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "$ESCAPED_FULL"
fi
