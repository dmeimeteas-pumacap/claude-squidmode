#!/bin/bash
set -euo pipefail

# UserPromptSubmit hook â€” `expand` keyword handler.
#
# When the user's prompt is exactly "expand" (case-insensitive, surrounding
# whitespace allowed), inject an overview of every active thread as
# additionalContext and let the prompt proceed, so the model renders it as a
# proper markdown table in normal styling. (Blocking with a `reason` was tried
# first but the harness shows block messages as unstyled plain text wrapped in
# yellow "operation blocked by hook" chrome â€” raw pipes, wrong color.)
#
# Delivery is reliable because this payload is small and is injected at prompt
# time â€” unlike the original SessionStart instruction, which got persisted to a
# file past the 2 KB preview, so the model never saw it and `expand` did nothing.
#
# Any other prompt: exit 0 with no output, leaving the prompt untouched.
#
# Table-rendering logic mirrors the (now-removed) EXPAND_ROWS builder in
# session-start-global.sh; this hook is its single owner.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
THREADS_INDEX="$CLAUDE_DIR/threads/INDEX.md"

# --- Cheap keyword gate (runs on EVERY prompt; keep it light) -------------
# Pull the "prompt" string out of the stdin payload with one sed pass. No jq
# dependency (matches session-start-global.sh's pure-bash posture). Tolerates
# optional whitespace after the colon and handles backslash escapes in the
# value. Only the bare keyword triggers; everything else falls through.
PAYLOAD="$(cat)"
prompt="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p')"
prompt="${prompt#"${prompt%%[![:space:]]*}"}"
prompt="${prompt%"${prompt##*[![:space:]]}"}"
prompt="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

[ "$prompt" = "expand" ] || exit 0

# --- Helpers --------------------------------------------------------------
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  REPLY="$s"
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Emit a block-decision response with $1 as the user-facing message, then exit.
block() {
  printf '{"decision":"block","reason":"%s"}\n' "$(json_escape "$1")"
  exit 0
}

# --- Gather active threads ------------------------------------------------
[ -f "$THREADS_INDEX" ] || block "No threads/INDEX.md found at $THREADS_INDEX."
ACTIVE_ROWS=$(awk '/^## Active/{f=1;next} /^## /{f=0} f && /^[|] *\[\[/' "$THREADS_INDEX" || true)
[ -n "$ACTIVE_ROWS" ] || block "No active threads to expand."

# Pre-parse the topic line for every thread file in a single awk pass (mirrors
# session-start-global.sh; topic is absent from the INDEX rows themselves).
mapfile -t _rows_arr <<< "$ACTIVE_ROWS"
declare -A TOPIC_MAP
_files=()
for _r in "${_rows_arr[@]}"; do
  IFS='|' read -r _ _s _ <<< "$_r"
  trim "$_s"; _s="$REPLY"
  _s="${_s//\[/}"; _s="${_s//\]/}"
  _f="$CLAUDE_DIR/threads/active/${_s}.md"
  [ -f "$_f" ] && _files+=("$_f")
done
if [ ${#_files[@]} -gt 0 ]; then
  while IFS=$'\t' read -r _k _val; do
    TOPIC_MAP["$_k"]="$_val"
  done < <(awk '
    FNR==1 { fn=FILENAME; sub(/.*\//,"",fn); sub(/\.md$/,"",fn); t=0 }
    /^topic:/ && !t { v=$0; sub(/^topic:[[:space:]]*/,"",v); print fn "\t" v; t=1 }
  ' "${_files[@]}")
fi

# --- Build the overview table (overview columns only; no Next step â€” that
# detail is /catchupall's job) -------------------------------------------
EXPAND_ROWS=""
ROW_NUM=0
while IFS= read -r row; do
  ROW_NUM=$((ROW_NUM + 1))
  IFS='|' read -r _ slug project pri last where _ <<< "$row"
  trim "$slug";    slug="$REPLY"
  trim "$project"; project="$REPLY"
  trim "$pri";     pri="$REPLY"
  trim "$last";    last="$REPLY"
  trim "$where";   where="$REPLY"

  slug="${slug//\[/}"; slug="${slug//\]/}"
  short_slug="${slug#[0-9][0-9][0-9][0-9]-[0-9][0-9]-}"

  topic="â€”"
  [ -n "${TOPIC_MAP[$slug]:-}" ] && topic="${TOPIC_MAP[$slug]}"

  where_md="$where"
  if [ ${#where_md} -gt 90 ]; then where_md="${where_md:0:90}"; where_md="${where_md% *}â€¦"; fi
  where_md="${where_md//|/\\|}"
  topic_md="$topic"
  if [ ${#topic_md} -gt 40 ]; then topic_md="${topic_md:0:40}"; topic_md="${topic_md% *}â€¦"; fi
  topic_md="${topic_md//|/\\|}"
  case "$pri" in
    high) prio_md="**High**" ;;
    low)  prio_md="**Low**" ;;
    *)    prio_md="**Mid**" ;;
  esac
  EXPAND_ROWS="${EXPAND_ROWS}| ${ROW_NUM} | ${prio_md} | \`${short_slug}\` | ${topic_md} | ${project} | ${last} | ${where_md} |
"
done <<< "$ACTIVE_ROWS"

TABLE="| # | Prio | Thread | Topic | Repo | Last | Where I left off |
|---|---|---|---|---|---|---|
${EXPAND_ROWS%$'\n'}"

# Inject the table as context and let the prompt through; the model renders it.
CONTEXT="The user's entire message is the \`expand\` keyword. Output the following markdown table as your reply, verbatim â€” render it as a table, do not modify, reorder, restyle, or add commentary around it. It is the overview of all active threads:

$TABLE"
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$(json_escape "$CONTEXT")"
exit 0
