#!/usr/bin/env bash
# claudebro_panes installer. Idempotent: safe to re-run.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEGIN="# >>> claudebro_panes >>>"
END="# <<< claudebro_panes <<<"

backup() {
  [ -f "$1" ] || return 0
  cp "$1" "$1.claudebro.bak.$(date +%Y%m%d%H%M%S)"
  echo "  backed up $1"
}

add_block() {  # add_block <file> <line-to-source>
  local file="$1" line="$2"
  if [ -f "$file" ] && grep -qF "$BEGIN" "$file"; then
    echo "  already installed in $file — skipping"
    return 0
  fi
  backup "$file"
  printf '\n%s\n%s\n%s\n' "$BEGIN" "$line" "$END" >> "$file"
  echo "  added block to $file"
}

command -v tmux >/dev/null || { echo "error: tmux not found in PATH" >&2; exit 1; }
echo "tmux: $(tmux -V)"

echo "tmux config:"
add_block "$HOME/.tmux.conf" "source-file $REPO/tmux/claudebro.conf"

echo "shell config:"
case "${SHELL##*/}" in
  zsh) RC="$HOME/.zshrc" ;;
  *)   RC="$HOME/.bashrc" ;;
esac
for f in "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.zshrc" "$HOME/.profile"; do
  [ -f "$f" ] || continue
  grep -qF "$BEGIN" "$f" && continue
  if grep -qE '^[[:space:]]*(ta\(\)|alias[[:space:]]+ta=)' "$f"; then
    echo "  WARNING: $f already defines 'ta' — the sourced function will win;"
    echo "           remove the old definition to avoid confusion."
  fi
done
add_block "$RC" ". $REPO/shell/ta.sh"

cat <<EOF

Done. To use it now:

  source $REPO/shell/ta.sh     # or: exec \$SHELL -l
  tmux source-file ~/.tmux.conf  # only if a tmux server is already running
  ta

Optional: see claude/CLAUDE.snippet.md for the ~/.claude/CLAUDE.md section
that tells Claude Code how to drive the bottom pane.
EOF
