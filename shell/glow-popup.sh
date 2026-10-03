#!/usr/bin/env bash
# glow-popup.sh — markdown reader for the Ctrl-b v popup, in Nord.
#
# An fzf list of the markdown files under the current directory, with a
# rendered preview. fzf takes the mouse: click (or tap) a file to highlight
# it, double-click or Enter to read it in glow; q in glow comes back to the
# list, Esc closes. (glow's own file browser ignores clicks.)
#
# The reader runs glow --mouse, so the wheel (or a swipe, in tablet SSH
# apps) scrolls; Shift-drag selects text. --mouse is hidden from glow's
# --help but is in v3's source. With arguments, glow runs on them directly.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/popup-common.sh"

command -v glow >/dev/null || { echo "glow is not installed"; read -r -n 1 -s; exit 0; }
claudebro_truecolor
style="$here/../glow/nord.json"

if [ $# -gt 0 ] || ! command -v fzf >/dev/null; then
  exec glow --mouse -s "$style" "$@"
fi

# fd skips .git and anything gitignored; plain find is the fallback.
list_md() {
  if command -v fd >/dev/null; then fd --type f -e md -e markdown
  elif command -v fdfind >/dev/null; then fdfind --type f -e md -e markdown
  else find . -type f \( -name '*.md' -o -name '*.markdown' \) -not -path '*/.git/*' | sed 's|^\./||'
  fi | sort
}

files=$(list_md)
if [ -z "$files" ]; then
  echo "No markdown files under $PWD"
  read -r -n 1 -s
  exit 0
fi

# fzf runs these through a shell, so the style path is quoted.
s=$(printf '%q' "$style")
read_cmd="glow --mouse -t -s $s {}"
fzf "$CLAUDEBRO_FZF_NORD" --reverse --prompt='markdown> ' \
  --header='click: highlight · double-click/Enter: read · Esc: close' \
  --preview "glow -s $s -w \$FZF_PREVIEW_COLUMNS {}" \
  --preview-window='right,65%' \
  --bind "enter:execute($read_cmd)" \
  --bind "double-click:execute($read_cmd)" <<<"$files"
exit 0
