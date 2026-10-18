#!/bin/sh
# state.sh EVENT — Claude Code hook that records what this Claude is doing
# in its tmux pane's @cb_busy option, for the ○ / ● / ◆ glyphs in the
# window tabs, the session name and the session picker (tmux/claudebro.conf's
# @cb_state). Claude Code's own pane title can't be used for this: it starts
# with ✳ whether Claude is working or idle.
#   busy    (UserPromptSubmit, PostToolUse)  @cb_busy=1     ● working
#   notify  (Notification)                   @cb_busy=wait  ◆ needs you,
#           unless it's the "waiting for your input" nudge, which is idle
#   idle    (Stop, SessionStart, SessionEnd) unset          ○ idle
# Runs synchronously (a single tmux call) so a late Stop can't overwrite the
# next prompt's busy. Outside tmux it does nothing.
[ -n "${TMUX_PANE:-}" ] || exit 0
case "${1:-}" in
  busy) tmux set -p -t "$TMUX_PANE" @cb_busy 1 ;;
  notify)
    if grep -q '"notification_type" *: *"idle_prompt"'; then
      tmux set -p -u -t "$TMUX_PANE" @cb_busy
    else
      tmux set -p -t "$TMUX_PANE" @cb_busy wait
    fi ;;
  idle) tmux set -p -u -t "$TMUX_PANE" @cb_busy ;;
esac 2>/dev/null
exit 0
