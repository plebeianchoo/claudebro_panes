#!/usr/bin/env bash
# team-window.sh — the Ctrl-b C "team" window: one read-only mirror pane per
# Claude pane (pane_current_command == claude), stacked. Creates the window,
# or switches to it if it exists. Enter in a mirror jumps to the real pane.
#
# Overrides, for testing: CLAUDEBRO_TEAM_NAME (window name, default team),
# CLAUDEBRO_TEAM_SESSION (session to put it in, default the current one),
# CLAUDEBRO_TEAM_DETACH=1 (don't switch to the window; print its name).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
name="${CLAUDEBRO_TEAM_NAME:-team}"
sess="${CLAUDEBRO_TEAM_SESSION:-$(tmux display -p '#{session_id}')}"

show() { [ -n "${CLAUDEBRO_TEAM_DETACH:-}" ] || tmux select-window -t "$1"; }

existing=$(tmux list-windows -t "$sess" -F '#{window_id} #{window_name}' |
  awk -v n="$name" '{ id=$1; $1=""; if (substr($0,2)==n) { print id; exit } }')
if [ -n "$existing" ]; then
  show "$existing"
  exit 0
fi

# Every Claude pane, in window order, except any inside a window named $name.
mapfile -t panes < <(tmux list-panes -a \
  -F '#{pane_id} #{pane_current_command} #{window_name}' |
  awk -v n="$name" '$2 == "claude" { w=$0; sub(/^[^ ]+ [^ ]+ /, "", w); if (w != n) print $1 }')
if [ "${#panes[@]}" -eq 0 ]; then
  tmux display-message "team: no Claude panes found"
  exit 0
fi

mirror="'$here/team-mirror.sh'"
first=1
for p in "${panes[@]}"; do
  label=$(tmux display -p -t "$p" 'mirror: #{session_name}:#{window_name}')
  if [ "$first" -eq 1 ]; then
    win=$(tmux new-window -d -t "$sess:" -n "$name" -P -F '#{window_id}' "$mirror '$p'")
    first=0
    last=$(tmux list-panes -t "$win" -F '#{pane_id}')
  else
    last=$(tmux split-window -d -v -t "$last" -P -F '#{pane_id}' "$mirror '$p'")
  fi
  tmux select-pane -t "$last" -T "$label"
  tmux select-layout -t "$win" even-vertical    # keep room for each split
done
show "$win"
echo "$name"
