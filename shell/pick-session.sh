#!/usr/bin/env bash
# pick-session.sh CLIENT — fuzzy session switcher, run inside a tmux popup.
# Sessions with a Claude waiting on a prompt sort first, then sessions with
# a bell (e.g. Claude finished), marked "!". Each shows its Claude state
# like the bottom left: ◆ waits on you, ● working, ○ idle (tmux's @cb_sess).
# Enter switches CLIENT to the highlighted session; typing a name that
# matches nothing and pressing Enter creates it with the ta layout.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/popup-common.sh"
claudebro_truecolor
client="${1:-}"

if ! command -v fzf >/dev/null; then
  echo "fzf is not installed — use Ctrl-b s, or click the session name."
  read -r -n 1 -s
  exit 0
fi

# Fields: urgency (2 waiting, 1 bell, 0 neither), last activity, flag +
# state, name, details. Sorted most urgent first, then most recently
# active; only flag/name/details are shown.
out=$(tmux list-sessions -F \
  '#{?#{m:*◆*,#{E:@cb_glyphs}},2,#{?session_alerts,1,0}}	#{session_activity}	#{?session_alerts,!, }#{?#{E:@cb_sess},#{E:@cb_sess},  }	#{session_name}	#{session_windows}w#{?session_attached, · attached,}' |
  sort -t $'\t' -k1,1nr -k2,2nr |
  fzf "$CLAUDEBRO_FZF_NORD" --delimiter=$'\t' --with-nth=3.. --reverse --print-query \
      --prompt='session> ' --header='Enter: switch · new name + Enter: create')
status=$?

query=$(sed -n 1p <<<"$out")
pick=$(sed -n 2p <<<"$out" | cut -f4)

case $status in
  0) exec "$here/claudebro-session" "$pick" "$client" ;;
  1) [ -n "$query" ] && exec "$here/claudebro-session" "$query" "$client" ;;
esac
exit 0
