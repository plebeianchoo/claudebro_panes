# claudebro_panes — the `ta` session launcher. Sourced from your shell rc.
#
#   ta [name]   Attach to a tmux session (default: main), creating it if it
#               does not exist. A new session is two stacked panes: the top
#               (~70%) runs Claude Code, the bottom is a plain shell for
#               commands. An existing session is attached to untouched.
#
# Environment:
#   CLAUDEBRO_CMD    command run in the top pane   (default: claude)
#   CLAUDEBRO_SPLIT  bottom pane height, percent   (default: 30)

ta() {
  local s="${1:-main}"
  local cmd="${CLAUDEBRO_CMD:-claude}"
  local split="${CLAUDEBRO_SPLIT:-30}"
  local top bottom

  if ! tmux has-session -t "$s" 2>/dev/null; then
    # Address panes by id (%N) rather than by index: index addressing like
    # "$s:1.1" silently targets the wrong pane on a machine that does not set
    # base-index / pane-base-index to 1.
    top=$(tmux new-session -d -s "$s" -c "$PWD" -P -F '#{pane_id}' \
            -x "$(tput cols 2>/dev/null || echo 200)" \
            -y "$(tput lines 2>/dev/null || echo 50)") || return 1

    # -l <n>% needs tmux 3.1; fall back to the deprecated -p for older tmux.
    bottom=$(tmux split-window -v -l "${split}%" -t "$top" -c "$PWD" \
               -P -F '#{pane_id}' 2>/dev/null) \
      || bottom=$(tmux split-window -v -p "$split" -t "$top" -c "$PWD" \
                    -P -F '#{pane_id}') || return 1

    tmux set -p -t "$top"    @role claude
    tmux set -p -t "$bottom" @role commands
    tmux select-pane -t "$top"

    # Start Claude only once a client has attached. Started in a still
    # detached session, the terminal's reply to Claude's background-colour
    # query (OSC 11) arrives too late to be consumed and is drawn as literal
    # ^[]11;rgb:... text. The hook unsets itself, so reattaching later does
    # not launch a second Claude.
    tmux set-hook -t "$s" client-attached \
      "send-keys -t $top '$cmd' Enter ; set-hook -ut $s client-attached"
  fi

  tmux attach -t "$s"
}

# tn [name] — same as ta. Shadows the common `tn` = `tmux new -s` alias so a
# new named session gets the layout too.
alias tn=ta
