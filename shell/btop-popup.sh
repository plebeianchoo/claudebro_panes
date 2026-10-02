#!/usr/bin/env bash
# btop-popup.sh — btop for the Ctrl-b b popup, in the Nord theme.
# Uses its own config file, so a plain `btop` keeps its own look and
# settings. The popup config starts as a copy of your btop.conf (or btop's
# defaults); settings changed inside the popup stick to it, but the theme
# is put back to Nord on every launch.
set -eu
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dir="${XDG_CONFIG_HOME:-$HOME/.config}/btop"
conf="$dir/claudebro-popup.conf"

command -v btop >/dev/null || { echo "btop is not installed"; exit 1; }
mkdir -p "$dir"
if [ ! -f "$conf" ]; then
  if [ -f "$dir/btop.conf" ]; then cp "$dir/btop.conf" "$conf"
  else btop --default-config > "$conf"
  fi
fi
if grep -q '^color_theme' "$conf"; then
  sed -i 's|^color_theme *=.*|color_theme = "nord"|' "$conf"
else
  echo 'color_theme = "nord"' >> "$conf"
fi
exec btop -c "$conf" --themes-dir "$repo/btop/themes"
