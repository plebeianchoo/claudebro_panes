#!/usr/bin/env bash
# prompts-popup.sh WINDOW — canned prompts for the Ctrl-b P popup, so a
# tablet's on-screen keyboard isn't needed for the usual replies. Picks a
# line from the prompts file and types it into the Claude pane of WINDOW
# (Enter: type only, to edit or add to it; Ctrl-S: type and send). Text that
# matches no line is typed as given, so the popup also works as a typing box.
# Ctrl-E edits the list.
#
# The list is ~/.config/claudebro/prompts.txt when it exists, else this
# repo's prompts.txt; Ctrl-E copies the repo's one there before editing.
# One prompt per line; blank lines and lines starting with # are skipped.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/popup-common.sh"
claudebro_truecolor
window="${1:-}"

mine="${XDG_CONFIG_HOME:-$HOME/.config}/claudebro/prompts.txt"
list() {
  local f="$here/../prompts.txt"
  [ -f "$mine" ] && f="$mine"
  grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$f"
}
# --list: just print the list (fzf's reload after Ctrl-E calls this).
[ "$window" = --list ] && { list; exit 0; }

# Claude's pane in that window: the one ta() marked @role=claude, else any
# pane running claude.
pane=$(tmux list-panes -t "$window" -F '#{pane_id} #{@role}' 2>/dev/null | awk '$2 == "claude" { print $1; exit }')
[ -n "$pane" ] || pane=$(tmux list-panes -t "$window" -F '#{pane_id} #{pane_current_command}' 2>/dev/null | awk '$2 == "claude" { print $1; exit }')
if [ -z "$pane" ]; then
  echo "No Claude pane in this window."
  read -r -n 1 -s
  exit 0
fi

if ! command -v fzf >/dev/null; then
  read -r -p "prompt: " text
  [ -n "$text" ] && tmux send-keys -t "$pane" -l -- "$text"
  exit 0
fi

# Ctrl-E: start a personal copy from the repo's list, edit it, reload.
edit="mkdir -p $(printf '%q' "${mine%/*}") && { [ -f $(printf '%q' "$mine") ] || cp $(printf '%q' "$here/../prompts.txt") $(printf '%q' "$mine"); } && \${VISUAL:-\${EDITOR:-nano}} $(printf '%q' "$mine")"

out=$(list | fzf "$CLAUDEBRO_FZF_NORD" --reverse --print-query --expect=ctrl-s \
        --prompt='prompt> ' \
        --header='Enter: type it · Ctrl-S: type + send · Ctrl-E: edit list' \
        --bind "ctrl-e:execute($edit)+reload($(printf '%q' "$here/prompts-popup.sh") --list)")
status=$?

query=$(sed -n 1p <<<"$out")
key=$(sed -n 2p <<<"$out")
text=$(sed -n 3p <<<"$out")
# Exit 1 is "no match": type the query itself.
[ $status -eq 1 ] && text=$query
[ $status -le 1 ] && [ -n "$text" ] || exit 0

tmux send-keys -t "$pane" -l -- "$text"
[ "$key" = ctrl-s ] && tmux send-keys -t "$pane" Enter
tmux select-pane -t "$pane"
exit 0
