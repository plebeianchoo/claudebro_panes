#!/usr/bin/env bash
# pin-layout.sh WINDOW — run by the window-resized hook in claudebro.conf.
#
# Stops an on-screen keyboard (a tablet in Termius) from pushing Claude's
# pane up. A keyboard shows up as the window getting shorter at the same
# width, so for each width this remembers the tallest and shortest window
# seen. Once the shortest is a real drop (at most 80% of the tallest),
# Claude's pane is pinned to what fits with the keyboard up: shortest - 2
# borders - 1 shell row. The shell then takes every resize and Claude never
# moves. The first keyboard at a new width (font size, rotation) still jumps
# once; that is when it is learned.
#
# The pin is only used when Claude keeps at least @cb_pin_keep percent
# (default 50) of the room it has with the keyboard down. On the tablet that
# means portrait (152x90 -> 152x56: Claude 52 of 86 rows) is pinned and
# landscape (229x59 -> 229x28: 24 of 56) is left to tmux. Desktops never
# shrink like this, so they are never pinned.
#
# Only a window that is exactly ta()'s two stacked panes (@role claude above
# @role commands) is touched. When a pin no longer applies, the window gets
# ta()'s 30% shell back. What it learned lives in global tmux options
# (@cb_kb_max_<width>, @cb_kb_min_<width>) until the tmux server restarts.
set -u
w="${1:-}"
[ -n "$w" ] || exit 0

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

get() { tmux show -gv "$1" 2>/dev/null; }
keep=$(get @cb_pin_keep); keep=${keep:-50}
max=$(get "@cb_kb_max_$ww"); min=$(get "@cb_kb_min_$ww")
if [ -z "$max" ] || [ "$wh" -gt "$max" ]; then max=$wh; tmux set -g "@cb_kb_max_$ww" "$max"; fi
if [ -z "$min" ] || [ "$wh" -lt "$min" ]; then min=$wh; tmux set -g "@cb_kb_min_$ww" "$min"; fi

pin=$(( min - 3 ))
if [ $(( min * 100 )) -le $(( max * 80 )) ] && [ $(( pin * 100 )) -ge $(( (max - 3) * keep )) ]; then
  h=$(( wh - 3 < pin ? wh - 3 : pin ))
  [ "$h" -ge 1 ] || exit 0
  tmux resize-pane -t "$claude" -y "$h"
  tmux set -w -t "$w" @cb_pinned 1
elif [ "$(tmux show -wv -t "$w" @cb_pinned 2>/dev/null)" = 1 ]; then
  tmux resize-pane -t "$shell" -y $(( wh * 30 / 100 ))
  tmux set -wu -t "$w" @cb_pinned
fi
exit 0
