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

add_file_block() {  # add_file_block <file> <source-content-file>
  # Unlike add_block, an existing block is replaced rather than skipped, so
  # re-running install.sh after a pull brings the copied text up to date.
  local file="$1" src="$2"
  mkdir -p "$(dirname "$file")"
  if [ -f "$file" ] && grep -qF "$BEGIN" "$file"; then
    backup "$file"
    awk -v s="$BEGIN" -v e="$END" -v src="$src" '
      index($0, s) { print; while ((getline l < src) > 0) print l; skip = 1; next }
      index($0, e) { skip = 0 }
      !skip        { print }
    ' "$file" > "$file.claudebro.tmp"
    mv "$file.claudebro.tmp" "$file"
    echo "  updated block in $file"
    return 0
  fi
  backup "$file"
  { echo; echo "$BEGIN"; cat "$src"; echo "$END"; } >> "$file"
  echo "  added to $file"
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
  for name in ta tn; do
    if grep -qE "^[[:space:]]*($name\(\)|alias[[:space:]]+$name=)" "$f"; then
      echo "  WARNING: $f already defines '$name' — the sourced one will win;"
      echo "           remove the old definition to avoid confusion."
    fi
  done
done
add_block "$RC" ". $REPO/shell/ta.sh"

echo "tldr pages (Ctrl-b h):"
pages="$HOME/.local/share/tealdeer/pages"
mkdir -p "$pages"
for page in "$REPO"/tldr/pages/*.md; do
  link="$pages/$(basename "$page")"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "  WARNING: $link is your own page — leaving it alone"
    continue
  fi
  ln -sfn "$page" "$link"
  echo "  linked $(basename "$page")"
done

echo
echo "claude/USAGE.md tells Claude Code it runs in the top pane and how to"
echo "drive the bottom one (find it by @role, send-keys / capture-pane)."
if [ -t 0 ]; then
  read -r -p "Add it to ~/.claude/CLAUDE.md now? [y/N] " ans
else
  ans=n
  echo "  (non-interactive — skipping; add it yourself later if you want it)"
fi
case "$ans" in
  [Yy]*) add_file_block "$HOME/.claude/CLAUDE.md" "$REPO/claude/USAGE.md" ;;
  *)     echo "  skipped — see $REPO/claude/USAGE.md to add manually" ;;
esac

echo
echo "claude/bell.sh rings the bell in Claude's pane when it finishes or needs"
echo "you, so tmux can flag that session in the status bar (Claude Code hooks)."
if [ -t 0 ]; then
  read -r -p "Add the hooks to ~/.claude/settings.json now? [y/N] " ans
else
  ans=n
  echo "  (non-interactive — skipping; run claude/hooks.sh install later)"
fi
case "$ans" in
  [Yy]*) "$REPO/claude/hooks.sh" install ;;
  *)     echo "  skipped — run $REPO/claude/hooks.sh install to add them" ;;
esac

cat <<EOF

Done. To use it now:

  source $REPO/shell/ta.sh     # or: exec \$SHELL -l
  tmux source-file ~/.tmux.conf  # only if a tmux server is already running
  ta
EOF
