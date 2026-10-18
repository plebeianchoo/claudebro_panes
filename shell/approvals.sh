#!/usr/bin/env bash
# approvals.sh — the Ctrl-b A popup: every Claude pane (in any session) that
# is waiting on a prompt you answer by picking an option (a permission
# prompt, an AskUserQuestion, the folder-trust check), with the selected
# one's prompt shown below the list. Keys:
#   1-9      answer the selected prompt (sent to that Claude as the digit)
#   Esc      cancel it (Claude's "No, and tell Claude what to do")
#   ↑↓ / kj  pick another prompt
#   Enter    jump to that Claude's pane (closes the popup)
#   q        close
# Closes by itself once you've answered the last one.
#
# A pane counts as waiting when its last non-blank line has "Esc to cancel"
# (the footer of all of Claude Code's choice dialogs). Before sending a key
# the pane is re-read, and the key is dropped if its prompt has changed.
#
# --count prints how many are waiting. --status stores that count in the
# global @cb_waiting option for the status bar's chip, and prints nothing.
set -u

# waiting_panes: "pane_id|session:window|topic" for each waiting Claude.
waiting_panes() {
  local pane loc cmd title
  tmux list-panes -a -F '#{pane_id}|#{session_name}:#{window_index}|#{pane_current_command}|#{pane_title}' |
  while IFS='|' read -r pane loc cmd title; do
    [ "$cmd" = claude ] || continue
    tmux capture-pane -p -t "$pane" 2>/dev/null | awk 'NF { l = $0 } END { exit l !~ /Esc to cancel/ }' &&
      printf '%s|%s|%s\n' "$pane" "$loc" "${title#[!a-zA-Z0-9]* }"
  done
}

# prompt_of PANE [-e]: the dialog at the bottom of PANE, blank lines dropped.
# It starts at the last full-width rule (─) above option "1." — or above the
# end, for dialogs without numbered options. -e keeps colours, for display;
# the rule search runs on the plain text, which has the same lines.
prompt_of() {
  local plain start
  plain=$(tmux capture-pane -p -t "$1" 2>/dev/null) || return 1
  start=$(printf '%s\n' "$plain" | awk '
    /^(─)+$/ { rule = NR }
    /^ *(❯ )?1\. / { at = rule }
    END { print (at ? at : rule) + 1 }')
  if [ "${2:-}" = -e ]; then
    tmux capture-pane -ep -t "$1" 2>/dev/null
  else
    printf '%s\n' "$plain"
  fi | tail -n +"$start" | awk '{ t = $0; gsub(/\033\[[0-9;]*m/, "", t) } t ~ /[^ ]/'
}

case "${1:-}" in
  --count)  waiting_panes | wc -l | tr -d ' '; exit 0 ;;
  --status) tmux set -g @cb_waiting "$(waiting_panes | wc -l | tr -d ' ')"; exit 0 ;;
esac

sel=""          # selected pane id; survives the list reordering
answered=0      # closes on an empty queue only after an answer from here
printf '\033[?25l\033[?7l'            # hide cursor, no line wrapping
trap 'printf "\033[?25h\033[?7h"' EXIT

while :; do
  rows=$(tput lines)
  mapfile -t queue < <(waiting_panes)
  n=${#queue[@]}
  if [ "$n" -eq 0 ] && [ "$answered" -eq 1 ]; then
    tmux set -g @cb_waiting 0; exit 0
  fi

  # Keep the selection on the same pane; fall back to the first.
  i=0; idx=0
  for row in "${queue[@]}"; do
    [ "${row%%|*}" = "$sel" ] && idx=$i
    i=$((i + 1))
  done
  [ "$n" -gt 0 ] && sel=${queue[idx]%%|*} || sel=""
  shown=""; [ -n "$sel" ] && shown=$(prompt_of "$sel")

  frame=$(
    if [ "$n" -eq 0 ]; then
      printf '\033[1mNo Claude is waiting on you.\033[0m New prompts show up here.\n'
    else
      printf '\033[1mWaiting on you: %d\033[0m\n' "$n"
      i=0
      for row in "${queue[@]}"; do
        IFS='|' read -r pane loc topic <<<"$row"
        if [ "$i" -eq "$idx" ]; then
          printf '\033[7m ▸ %-8s %s \033[0m\n' "$loc" "$topic"
        else
          printf '   %-8s %s\n' "$loc" "$topic"
        fi
        i=$((i + 1))
      done
      printf '\033[2m%s\033[0m\n' "────────────────────────────────────────"
      prompt_of "$sel" -e
    fi
  )
  # Leave the last row for the key help.
  printf '\033[H%s\033[J' "$(printf '%s\n' "$frame" | head -n "$((rows - 1))" | sed $'s/$/\033[0m\033[K/')"
  printf '\033[%d;1H\033[2m1-9 answer · Esc cancel · ↑↓ pick · Enter jump · q close\033[0m' "$rows"

  IFS= read -rsn1 -t 1 k || continue
  if [ "$k" = $'\e' ]; then
    # An arrow key arrives as Esc [ A; a lone Esc has nothing after it.
    IFS= read -rsn2 -t 0.05 rest || rest=""
    case "$rest" in
      '[A'|OA) k=up ;; '[B'|OB) k=down ;; '') k=esc ;; *) continue ;;
    esac
  fi
  case "$k" in
    q) exit 0 ;;
    up|k)   [ "$n" -gt 0 ] && sel=${queue[(idx + n - 1) % n]%%|*} ;;
    down|j) [ "$n" -gt 0 ] && sel=${queue[(idx + 1) % n]%%|*} ;;
    '')     [ -n "$sel" ] && { tmux switch-client -t "$sel"; exit 0; } ;;
    [1-9]|esc)
      [ -n "$sel" ] || continue
      # Send only if the prompt on screen is still the one shown.
      [ "$(prompt_of "$sel")" = "$shown" ] || continue
      if [ "$k" = esc ]; then
        tmux send-keys -t "$sel" Escape
      else
        printf '%s\n' "$shown" | grep -Eq "^ *(❯ )?$k\. " || continue
        tmux send-keys -t "$sel" "$k"
      fi
      answered=1
      # Give Claude a moment to redraw, so the next frame doesn't still
      # list this prompt.
      sleep 0.3
      ;;
  esac
done
