#!/usr/bin/env bash
# glow-popup.sh — markdown reader for the Ctrl-b v popup, in Nord. With no
# arguments glow opens its browser on the markdown files under the current
# directory: Enter reads one, Esc goes back, q quits.
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/popup-common.sh"

command -v glow >/dev/null || { echo "glow is not installed"; exit 1; }
claudebro_truecolor
exec glow -s "$here/../glow/nord.json" "$@"
