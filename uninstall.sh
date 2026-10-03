#!/usr/bin/env bash
# Removes the blocks install.sh added. Leaves backups and the repo alone.
set -euo pipefail

BEGIN="# >>> claudebro_panes >>>"
END="# <<< claudebro_panes <<<"

for f in "$HOME/.tmux.conf" "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.claude/CLAUDE.md"; do
  [ -f "$f" ] || continue
  grep -qF "$BEGIN" "$f" || continue
  cp "$f" "$f.claudebro.bak.$(date +%Y%m%d%H%M%S)"
  awk -v s="$BEGIN" -v e="$END" '
    index($0, s) { skip = 1 }
    !skip        { print }
    index($0, e) { skip = 0 }
  ' "$f" > "$f.claudebro.tmp"
  mv "$f.claudebro.tmp" "$f"
  echo "removed block from $f (backup kept)"
done
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for link in "$HOME"/.local/share/tealdeer/pages/*.md; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    "$REPO"/tldr/pages/*) rm "$link"; echo "removed tldr page link $link" ;;
  esac
done
"$REPO/claude/hooks.sh" uninstall
echo "Done. Restart your shell; run 'unset -f ta; unalias tn' to drop them from the current one."
