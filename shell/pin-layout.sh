#!/usr/bin/env bash
# pin-layout.sh WINDOW — run by the window-resized hook in claudebro.conf.
#
# On a narrow client (a tablet), keep Claude's pane at a fixed height so an
# on-screen keyboard shrinking the terminal takes every row from the shell
# below it, and Claude's prompt and transcript don't jump. Portrait tablet:
# 29 rows with the keyboard up = 1 status + 2 borders + 1 shell row + 25 for
# Claude, so 25 is the default.
#
# Only a window that is exactly ta()'s two stacked panes (@role claude above
# @role commands) is touched. On a wider client a window this pinned gets
# ta()'s 30% shell back; one it never pinned is left alone.
#
# Options (set -g in ~/.tmux.conf): @cb_pin_rows (default 25),
# @cb_pin_max_width (default 170 columns; wider clients aren't pinned).
set -u
w="${1:-}"
[ -n "$w" ] || exit 0

opt() { local v; v=$(tmux show -gv "$1" 2>/dev/null); echo "${v:-$2}"; }
pin=$(opt @cb_pin_rows 25)
maxw=$(opt @cb_pin_max_width 170)

read -r ww wh n < <(tmux display -p -t "$w" '#{window_width} #{window_height} #{window_panes}') || exit 0
[ "$n" = 2 ] || exit 0

claude=; shell=
while read -r id role top; do
  case $role in
    claude)   claude=$id; ctop=$top ;;
    commands) shell=$id;  stop=$top ;;
  esac
done < <(tmux list-panes -t "$w" -F '#{pane_id} #{@role} #{pane_top}')
[ -n "$claude" ] && [ -n "$shell" ] && [ "$ctop" -lt "$stop" ] || exit 0

if [ "$ww" -le "$maxw" ]; then
  # Two border rows and at least one shell row.
  h=$(( wh - 3 < pin ? wh - 3 : pin ))
  [ "$h" -ge 1 ] || exit 0
  tmux resize-pane -t "$claude" -y "$h"
  tmux set -w -t "$w" @cb_pinned 1
elif [ "$(tmux show -wv -t "$w" @cb_pinned 2>/dev/null)" = 1 ]; then
  tmux resize-pane -t "$shell" -y $(( wh * 30 / 100 ))
  tmux set -wu -t "$w" @cb_pinned
fi
exit 0
