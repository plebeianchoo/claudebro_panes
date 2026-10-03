#!/usr/bin/env bash
# lazygit-popup.sh — lazygit for the Ctrl-b g / [git] popup, in Nord.
# Loads your own lazygit config first and lazygit/nord.yml on top of it
# (later files win), so only the colours change, and a plain `lazygit`
# keeps its usual look.
set -eu
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v lazygit >/dev/null || { echo "lazygit is not installed"; exit 1; }
files="$repo/lazygit/nord.yml"
user="$(lazygit --print-config-dir)/config.yml"
[ -s "$user" ] && files="$user,$files"

. "$repo/shell/popup-common.sh"
claudebro_truecolor

# Outside a git repo lazygit only asks "Create a new git repository?", and
# q/Esc don't answer it. Offer lazygit's own recent repos instead (from its
# state file); Esc closes the popup.
if [ $# -eq 0 ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
  state="${XDG_STATE_HOME:-$HOME/.local/state}/lazygit/state.yml"
  recent=""
  if [ -f "$state" ]; then
    recent=$(awk '/^recentrepos:/ { f = 1; next }
                  f && /^[^ -]/   { f = 0 }
                  f && /^ *- /    { sub(/^ *- /, ""); gsub(/^["'\'']|["'\'']$/, ""); print }' "$state" |
             while IFS= read -r d; do [ -d "$d" ] && printf '%s\n' "$d"; done)
  fi
  if [ -z "$recent" ] || ! command -v fzf >/dev/null; then
    echo "Not in a git repository: $PWD"
    [ -z "$recent" ] && echo "(and lazygit has no recent repositories to offer)"
    read -r -n 1 -s -p "Press any key to close."
    exit 0
  fi
  pick=$(fzf "$CLAUDEBRO_FZF_NORD" --reverse --prompt='repo> ' \
           --header="Not a git repo: $PWD — pick a recent one · Esc: close" \
           --preview 'git -C {} -c color.status=always status -sb | head -15; echo; git -C {} log --oneline --color=always -15' \
           --preview-window='right,55%' <<<"$recent") || exit 0
  cd "$pick"
fi

exec lazygit --use-config-file "$files" "$@"
