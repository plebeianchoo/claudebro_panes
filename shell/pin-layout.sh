#!/usr/bin/env bash
# pin-layout.sh WINDOW WIDTH HEIGHT — run by the hooks in claudebro.conf with
# the client's size (HEIGHT without the status line) or, from window-resized,
# the window's.
#
# Stops an on-screen keyboard (a tablet in Termius) from pushing Claude's
# pane up. A keyboard shows up as the client getting shorter at the same
# width, so for each width this remembers the tallest and shortest seen.
# Once the shortest is a real drop (at most 80% of the tallest), the window
# is pinned:
#   - its size is set to manual, at the tallest height, so tmux no longer
#     resizes it when the keyboard comes and goes;
#   - Claude's pane gets what fits with the keyboard up: shortest - 2
#     borders - 1 shell row.
# With the keyboard up the client is shorter than the window and tmux shows
# its top part: all of Claude's pane, one shell row, the rest of the shell
# under the keyboard. No pane is resized, so Claude doesn't move or redraw.
# (Resizing panes to compensate can't avoid it: when a pane ends up at the
# size it started, tmux replays the in-between size first to force a
# redraw.) The first keyboard at a new width (font size, rotation) still
# jumps once; that is when it is learned.
#
# The pin is only used when Claude keeps at least @cb_pin_keep percent
# (default 50) of the room it has with the keyboard down. On the tablet that
# means portrait (152x90 -> 152x56: Claude 52 of 86 rows) is pinned and
# landscape (229x59 -> 229x28: 24 of 56) is left to tmux. Desktops never
# shrink like this, so they are never pinned. A client of another width
# hands a pinned window back to tmux with ta()'s 30% shell.
#
# Only a window that is exactly ta()'s two stacked panes (@role claude above
# @role commands) is touched. What it learned lives in global tmux options
# (@cb_kb_max_<width>, @cb_kb_min_<width>), saved as tmux commands to
# ~/.local/state/claudebro/keyboard.conf, which claudebro.conf loads, so a
# tmux restart doesn't make the first keyboard jump again.
set -u
w="${1:-}" cw="${2:-}" ch="${3:-}"
[ -n "$w" ] && [ -n "$cw" ] && [ -n "$ch" ] || exit 0

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
max=$(get "@cb_kb_max_$cw"); min=$(get "@cb_kb_min_$cw")
learned=
if [ -z "$max" ] || [ "$ch" -gt "$max" ]; then max=$ch; tmux set -g "@cb_kb_max_$cw" "$max"; learned=1; fi
if [ -z "$min" ] || [ "$ch" -lt "$min" ]; then min=$ch; tmux set -g "@cb_kb_min_$cw" "$min"; learned=1; fi
if [ -n "$learned" ]; then
  state="$HOME/.local/state/claudebro"
  mkdir -p "$state" &&
    tmux show -g | awk '/^@cb_kb_(max|min)_[0-9]+ / { print "set -g " $1 " " $2 }' > "$state/keyboard.conf.tmp" &&
    mv "$state/keyboard.conf.tmp" "$state/keyboard.conf"
fi
pinned=$(tmux show -wv -t "$w" @cb_pinned 2>/dev/null)

pin=$(( min - 3 ))
if [ $(( min * 100 )) -le $(( max * 80 )) ] && [ $(( pin * 100 )) -ge $(( (max - 3) * keep )) ]; then
  # Pinned, or becoming so: window at the tallest height, Claude at the pin.
  # Nothing to do when that's already the layout (the keyboard coming up).
  if [ "$pinned" != 1 ] || [ "$ww" != "$cw" ] || [ "$wh" != "$max" ] ||
     [ "$(tmux display -p -t "$claude" '#{pane_height}')" != "$pin" ]; then
    tmux resize-window -t "$w" -x "$cw" -y "$max" \; resize-pane -t "$claude" -y "$pin" \; \
         set -w -t "$w" @cb_pinned 1
  fi
elif [ "$pinned" = 1 ]; then
  # Hand the window back to tmux, sized to the client. resize-window sets
  # the size to manual, so window-size is unset after it.
  tmux set -wu -t "$w" @cb_pinned \; resize-window -A -t "$w" \; set -wu -t "$w" window-size
  read -r wh < <(tmux display -p -t "$w" '#{window_height}')
  tmux resize-pane -t "$shell" -y $(( wh * 30 / 100 ))
fi
exit 0
