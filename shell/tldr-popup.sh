#!/usr/bin/env bash
# tldr-popup.sh — cheat sheets for the Ctrl-b h popup. Fuzzy-search every
# tldr page with a live preview; Enter opens the page full-size (q returns
# to the list), Esc closes. Colours: tldr/nord.toml, used only here, so a
# plain `tldr` keeps your own config.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/popup-common.sh"

command -v tldr >/dev/null || { echo "tldr is not installed"; read -r -n 1 -s; exit 0; }
claudebro_truecolor
cfg="$here/../tldr/nord.toml"

if ! command -v fzf >/dev/null; then
  read -r -p "tldr page for: " cmd
  [ -n "$cmd" ] && tldr --config-path "$cfg" --color always "$cmd" | less -R
  exit 0
fi

# fzf runs --preview and execute() through a shell, so the path is quoted.
# stderr is dropped so tealdeer's "cache is old" warning stays out of every
# preview (run `tldr --update` now and then to refresh the pages).
page="tldr --config-path $(printf '%q' "$cfg") --color always {} 2>/dev/null"
tldr --list | fzf "$CLAUDEBRO_FZF_NORD" --reverse --prompt='tldr> ' \
  --header='Enter: full page · Esc: close' \
  --preview "$page" --preview-window='right,65%,wrap' \
  --bind "enter:execute($page | less -R)"
exit 0
