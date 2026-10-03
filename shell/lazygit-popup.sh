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
exec lazygit --use-config-file "$files" "$@"
