#!/usr/bin/env bash
# hooks.sh install|uninstall — add or remove the Stop and Notification hooks
# that run claude/bell.sh, in ~/.claude/settings.json. Merges with whatever
# hooks are already there and leaves them alone. Needs jq. Idempotent.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$REPO/claude/bell.sh"
F="$HOME/.claude/settings.json"

command -v jq >/dev/null || {
  echo "  jq not found — add Stop and Notification hooks running $CMD by hand"
  exit 0
}

has_hook() {
  [ -f "$F" ] && jq -e --arg c "$CMD" \
    '[.hooks // {} | .[][]?.hooks[]?.command] | index($c) != null' "$F" >/dev/null
}

write() {  # write <jq filter>
  cp "$F" "$F.claudebro.bak.$(date +%Y%m%d%H%M%S)"
  jq --arg c "$CMD" "$1" "$F" > "$F.claudebro.tmp"
  mv "$F.claudebro.tmp" "$F"
}

case "${1:-}" in
  install)
    if has_hook; then echo "  bell hooks already in $F — skipping"; exit 0; fi
    mkdir -p "$(dirname "$F")"
    [ -f "$F" ] || echo '{}' > "$F"
    write '.hooks.Stop += [{"hooks": [{"type": "command", "command": $c, "async": true}]}]
         | .hooks.Notification += [{"hooks": [{"type": "command", "command": $c, "async": true}]}]'
    echo "  added Stop and Notification bell hooks to $F (backup kept)"
    ;;
  uninstall)
    has_hook || exit 0
    # Drop our hook entries, then any matcher group or event left empty.
    write '.hooks |= (with_entries(.value |= (map(.hooks |= map(select(.command != $c)))
                                             | map(select(.hooks | length > 0))))
                     | with_entries(select(.value | length > 0)))'
    echo "  removed bell hooks from $F (backup kept)"
    ;;
  *) echo "usage: $0 install|uninstall" >&2; exit 2 ;;
esac
