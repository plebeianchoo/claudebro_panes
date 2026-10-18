#!/usr/bin/env bash
# status-scroll.sh SESSION left|right [CLIENT] — scroll the window tabs in
# the status bar, for the ‹ › buttons narrow clients get. tmux can't scroll
# its window list itself, so tabs left of the session's @cb_scroll_from
# window index draw as nothing (see @cb_hidden in tmux/claudebro.conf), and
# this moves that index one window along. Scrolled all the way left, the
# option is unset and tmux's own list (which keeps the current window in
# view) is back. Switching windows resets it the same way.
set -u
s="${1:?usage: status-scroll.sh SESSION left|right [CLIENT]}"
mapfile -t idx < <(tmux list-windows -t "$s" -F '#{window_index}')
from=$(tmux show -qv -t "$s" @cb_scroll_from)
from="${from:-${idx[0]}}"

# p: position of the first visible tab.
p=0
for i in "${!idx[@]}"; do [ "${idx[i]}" -lt "$from" ] && p=$((i + 1)); done
case "${2:-}" in
  right) [ "$p" -lt $((${#idx[@]} - 1)) ] && p=$((p + 1)) ;;
  left)  [ "$p" -gt 0 ] && p=$((p - 1)) ;;
esac

if [ "$p" -eq 0 ]; then
  tmux set -u -t "$s" @cb_scroll_from
else
  tmux set -t "$s" @cb_scroll_from "${idx[p]}"
fi
[ -n "${3:-}" ] && tmux refresh-client -S -t "$3"
exit 0
