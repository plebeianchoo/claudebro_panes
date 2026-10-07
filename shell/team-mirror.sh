#!/usr/bin/env bash
# team-mirror.sh PANE_ID — read-only live copy of a tmux pane's bottom lines,
# sized to this pane, refreshed every second. Run by team-window.sh inside
# each pane of the `team` window. Enter jumps to the real pane.
set -u
t="${1:?usage: team-mirror.sh PANE_ID}"
printf '\033[?25l\033[?7l'            # hide cursor, no line wrapping
trap 'printf "\033[?25h\033[?7h"' EXIT
while :; do
  h=$(tmux display -p -t "${TMUX_PANE:-}" '#{pane_height}' 2>/dev/null) || exit 0
  if ! out=$(tmux capture-pane -ep -t "$t" 2>/dev/null); then
    printf '\033[H\033[2J(pane %s is gone)' "$t"
  else
    # Home, then clear each line to its end as it is drawn: no flicker.
    printf '\033[H%s\033[J' "$(printf '%s\n' "$out" | tail -n "$h" | sed $'s/$/\033[K/')"
  fi
  # Wait up to 1s for a key; Enter reads as an empty string with status 0.
  if IFS= read -rsn1 -t 1 key && [ -z "$key" ]; then
    tmux switch-client -t "$t" 2>/dev/null
  fi
done
