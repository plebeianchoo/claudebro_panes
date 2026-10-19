#!/usr/bin/env bash
# team-glance.sh — the Ctrl-b T popup: one block per Claude pane across all
# sessions (window, state, idle time, title topic, last lines), then the
# "## Assigned" section of the team board. Read-only.
#
# On a terminal it redraws every 2s until you press q. With --once, or when
# stdout isn't a terminal (e.g. piped), it prints once and exits.
# CLAUDEBRO_BOARD overrides the board file.
set -u
board="${CLAUDEBRO_BOARD:-$HOME/workbench/.team/BOARD.md}"

render() {
  local cols="$1" now sid idx wname pane title act state idle topic cmd busy
  now=$(date +%s)
  tmux list-panes -a -F '#{session_name}|#{window_index}|#{window_name}|#{pane_id}|#{window_activity}|#{pane_current_command}|#{@cb_busy}|#{pane_title}' |
  while IFS='|' read -r sid idx wname pane act cmd busy title; do
    [ "$cmd" = claude ] || continue
    # @cb_busy is kept by claude/state.sh (the Claude Code hooks): 1 while a
    # turn runs, wait at a permission prompt or question, unset when idle.
    # The pane title can't tell: it starts with ✳ either way.
    case "$busy" in wait) state="◆ needs you" ;; 1) state="● working" ;; *) state="○ idle" ;; esac
    topic="${title#* }"; [ "$topic" = "$title" ] && topic="$title"
    idle=$((now - act)); [ "$idle" -lt 0 ] && idle=0
    printf '\033[1m%s:%s %s\033[0m  %s  (activity %dm%02ds ago)\n' \
      "$sid" "$idx" "$wname" "$state" $((idle / 60)) $((idle % 60))
    printf '  topic: %s\n' "$topic"
    # Last 4 lines that contain text (skips the TUI's box-drawing rows).
    tmux capture-pane -p -t "$pane" | grep -E '[[:alnum:]]' | tail -n 4 |
      cut -c1-"$((cols - 4))" | sed 's/^/  | /'
    echo
  done
  if [ -r "$board" ]; then
    printf '\033[1mBoard: Assigned\033[0m  (%s)\n' "$board"
    awk '/^## /{ on = ($0 ~ /^## Assigned/); next } on' "$board" | cut -c1-"$cols"
  fi
}

if [ "${1:-}" = --once ] || [ ! -t 1 ]; then
  render "${COLUMNS:-100}"
  exit 0
fi

printf '\033[?25l'; trap 'printf "\033[?25h"' EXIT
while :; do
  rows=$(tput lines); cols=$(tput cols)
  frame=$(render "$cols" | head -n "$((rows - 2))")
  printf '\033[H%s\033[J' "$(printf '%s\n' "$frame" | sed $'s/$/\033[K/')"
  printf '\033[%d;1H\033[2mq: quit · refreshes every 2s\033[0m' "$rows"
  IFS= read -rsn1 -t 2 k && [ "$k" = q ] && exit 0
done
