#!/bin/sh
# Claude Code hook for Stop and Notification: rings the terminal bell in
# Claude's own tmux pane, so tmux flags that session when Claude finishes or
# needs you (see the alert list in tmux/claudebro.conf's status-right).
# Writes to the pane's tty directly because hooks have no terminal of their
# own. Outside tmux it does nothing.
[ -n "${TMUX_PANE:-}" ] || exit 0
tty=$(tmux display -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null) || exit 0
[ -w "$tty" ] && printf '\a' > "$tty"
exit 0
