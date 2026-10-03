#!/usr/bin/env bash
# glow-popup.sh — markdown reader for the Ctrl-b v popup, in Nord. With no
# arguments glow opens its browser on the markdown files under the current
# directory: Enter reads one, Esc goes back, q quits. --mouse turns on
# wheel scrolling (tablet SSH apps send swipes as wheel events); glow hides
# the flag from --help, but it's in v3's source. Plain click-drag then goes
# to glow, so hold Shift to select text.
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/popup-common.sh"

command -v glow >/dev/null || { echo "glow is not installed"; exit 1; }
claudebro_truecolor
exec glow --mouse -s "$here/../glow/nord.json" "$@"
