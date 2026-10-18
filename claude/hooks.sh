#!/usr/bin/env bash
# hooks.sh install|uninstall — add or remove claudebro's Claude Code hooks in
# ~/.claude/settings.json: claude/bell.sh on Stop and Notification (the
# alert), and claude/state.sh on the events that say whether Claude is
# working, idle or waiting on you (the ○ / ● / ◆ glyphs). Merges with
# whatever hooks are already there and leaves them alone. Needs jq.
# Idempotent: install adds only the hooks that are missing.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BELL="$REPO/claude/bell.sh"
STATE="$REPO/claude/state.sh"
F="$HOME/.claude/settings.json"

# event|command|async — one line per hook.
HOOKS="Stop|$BELL|true
Notification|$BELL|true
UserPromptSubmit|$STATE busy|false
PostToolUse|$STATE busy|false
Notification|$STATE notify|false
Stop|$STATE idle|false
SessionStart|$STATE idle|false
SessionEnd|$STATE idle|false"

command -v jq >/dev/null || {
  echo "  jq not found — add these hooks to $F by hand (event, command):"
  cut -d'|' -f1,2 <<<"$HOOKS" | sed 's/|/  /; s/^/    /'
  exit 0
}

has_hook() {  # has_hook <event> <command>
  [ -f "$F" ] && jq -e --arg e "$1" --arg c "$2" \
    '[.hooks[$e] // [] | .[].hooks[]?.command] | index($c) != null' "$F" >/dev/null
}

# settings.json may be a symlink (e.g. into a dotfiles repo): write the file
# it points at, so the link survives. The backup goes next to the link.
write() {  # write <jq filter> [jq args...]
  local real filter="$1"; shift
  real=$(readlink -f "$F")
  cp "$real" "$F.claudebro.bak.$(date +%Y%m%d%H%M%S)"
  jq "$@" "$filter" "$real" > "$real.claudebro.tmp"
  mv "$real.claudebro.tmp" "$real"
}

case "${1:-}" in
  install)
    mkdir -p "$(dirname "$F")"
    [ -f "$F" ] || echo '{}' > "$F"
    added=0
    while IFS='|' read -r event cmd async; do
      has_hook "$event" "$cmd" && continue
      write '.hooks[$e] += [{"hooks": [{"type": "command", "command": $c, "async": ($a == "true")}]}]' \
        --arg e "$event" --arg c "$cmd" --arg a "$async"
      added=$((added + 1))
    done <<<"$HOOKS"
    if [ "$added" -eq 0 ]; then echo "  claudebro hooks already in $F — skipping"
    else echo "  added $added claudebro hook(s) to $F (backup kept)"; fi
    ;;
  uninstall)
    [ -f "$F" ] || exit 0
    jq -e --arg r "$REPO/claude/" \
      '[.hooks // {} | .[][]?.hooks[]?.command | select(startswith($r))] | length > 0' "$F" >/dev/null || exit 0
    # Drop every hook running a script from claude/ here, then any matcher
    # group or event left empty.
    write '.hooks |= (with_entries(.value |= (map(.hooks |= map(select(.command | startswith($r) | not)))
                                             | map(select(.hooks | length > 0))))
                     | with_entries(select(.value | length > 0)))' --arg r "$REPO/claude/"
    echo "  removed claudebro hooks from $F (backup kept)"
    ;;
  *) echo "usage: $0 install|uninstall" >&2; exit 2 ;;
esac
