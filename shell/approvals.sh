#!/usr/bin/env bash
# approvals.sh — the Ctrl-b A popup: every Claude pane (in any session) that
# is waiting on a prompt you answer by picking an option (a permission
# prompt, an AskUserQuestion, the folder-trust check). It opens as a grid of
# cards, one per prompt, each with the prompt's first lines and its options;
# Space switches to the selected prompt in full (and back). Keys:
#   1-9         answer the selected prompt (sent to that Claude as the digit)
#   Esc         cancel it (Claude's "No, and tell Claude what to do")
#   arrows/hjkl pick another prompt (Tab: next)
#   Space       cards / full prompt
#   Enter       jump to that Claude's pane (closes the popup)
#   q           close
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

# Card widths count characters, which needs a UTF-8 locale.
x="─"; [ "${#x}" -eq 1 ] || export LC_ALL=C.UTF-8

# fit TEXT WIDTH [PAD]: TEXT cut or padded (with spaces, or PAD) to exactly
# WIDTH characters.
fit() {
  local s="$1" w="$2" pad
  if [ "${#s}" -gt "$w" ]; then s="${s:0:w-1}…"; fi
  printf -v pad '%*s' $((w - ${#s})) ''
  printf '%s%s' "$s" "${pad// /${3:- }}"
}

# card_body PANE: a prompt boiled down for a card. Its first 3 lines of
# context (what is asked: "Bash command", the command, the question), then
# the first line of each option. Rules, the footer and tips are dropped.
# Dialogs without numbered options (folder trust) get a pointer instead.
card_body() {
  prompt_of "$1" | awk '
    /^[ ─╌]+$/ || /Esc to cancel|Enter to confirm/ || /^ *Tip:/ { next }
    /^ *(❯ )?[0-9]+\. / { sub(/^ +/, ""); if ($0 !~ /^❯/) $0 = "  " $0; opts = 1; print; next }
    !opts && ctx++ < 3 { sub(/^ +/, ""); print }
    END { if (!opts) print "(no numbered options: Enter to answer in the pane)" }'
}

# draw_cards IDX COLS ROWS: the queue as a grid of boxed cards, the selected
# one bold and highlighted, scrolled so it is on screen.
draw_cards() {
  local idx="$1" cols="$2" rows="$3" ncol w h r c i j line top bot
  ncol=$((cols / 46)); [ "$ncol" -lt 1 ] && ncol=1; [ "$ncol" -gt "$n" ] && ncol=$n
  w=$((cols / ncol - 1))             # outer card width, one space apart
  local -a bodies=()
  h=1
  for ((i = 0; i < n; i++)); do
    bodies[i]=$(card_body "${queue[i]%%|*}")
    j=$(printf '%s\n' "${bodies[i]}" | wc -l)
    [ "$j" -gt "$h" ] && h=$j
  done
  [ "$h" -gt 9 ] && h=9
  # Card rows that fit under the title line, and the first one to show.
  local fit_rows=$(( (rows - 2) / (h + 2) )); [ "$fit_rows" -lt 1 ] && fit_rows=1
  local first=$(( idx / ncol - fit_rows + 1 )); [ "$first" -lt 0 ] && first=0
  for ((r = first; r * ncol < n && r < first + fit_rows; r++)); do
    local -a out=()
    for ((c = 0; c < ncol; c++)); do
      i=$((r * ncol + c)); [ "$i" -lt "$n" ] || break
      IFS='|' read -r _ loc topic <<<"${queue[i]}"
      top="┌ $((i + 1)) · $loc $topic "
      top="$(fit "$top" $((w - 1)) ─)┐"
      bot="└$(fit '' $((w - 2)) ─)┘"
      if [ "$i" -eq "$idx" ]; then local on=$'\033[1;36m' off=$'\033[0m'; else local on='' off=''; fi
      out[0]+="$on$top$off "
      mapfile -t lines <<<"${bodies[i]}"
      for ((j = 0; j < h; j++)); do
        out[j + 1]+="$on│$off$(fit " ${lines[j]:-}" $((w - 2)))$on│$off "
      done
      out[h + 1]+="$on$bot$off "
    done
    printf '%s\n' "${out[@]}"
  done
  local shown_to=$(( (first + fit_rows) * ncol ))
  [ "$shown_to" -lt "$n" ] && printf '\033[2m  … %d more below\033[0m\n' $((n - shown_to))
  return 0
}

sel=""          # selected pane id; survives the list reordering
answered=0      # closes on an empty queue only after an answer from here
full=0          # 0: cards, 1: the selected prompt in full
printf '\033[?25l\033[?7l'            # hide cursor, no line wrapping
trap 'printf "\033[?25h\033[?7h"' EXIT

while :; do
  rows=$(tput lines); cols=$(tput cols)
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
  ncol=$((cols / 46)); [ "$ncol" -lt 1 ] && ncol=1   # as in draw_cards

  frame=$(
    if [ "$n" -eq 0 ]; then
      printf '\033[1mNo Claude is waiting on you.\033[0m New prompts show up here.\n'
    elif [ "$full" -eq 0 ]; then
      printf '\033[1mWaiting on you: %d\033[0m\n' "$n"
      draw_cards "$idx" "$cols" "$rows"
    else
      IFS='|' read -r _ loc topic <<<"${queue[idx]}"
      printf '\033[1m%d of %d · %s %s\033[0m\n' $((idx + 1)) "$n" "$loc" "$topic"
      printf '\033[2m%s\033[0m\n' "────────────────────────────────────────"
      prompt_of "$sel" -e
    fi
  )
  # Leave the last row for the key help.
  printf '\033[H%s\033[J' "$(printf '%s\n' "$frame" | head -n "$((rows - 1))" | sed $'s/$/\033[0m\033[K/')"
  if [ "$full" -eq 0 ]; then help='Space full prompt'; else help='Space cards'; fi
  printf '\033[%d;1H\033[2m1-9 answer · Esc cancel · arrows pick · %s · Enter jump · q close\033[0m' "$rows" "$help"

  IFS= read -rsn1 -t 1 k || continue
  if [ "$k" = $'\e' ]; then
    # An arrow key arrives as Esc [ A; a lone Esc has nothing after it.
    IFS= read -rsn2 -t 0.05 rest || rest=""
    case "$rest" in
      '[A'|OA) k=up ;; '[B'|OB) k=down ;; '[C'|OC) k=right ;; '[D'|OD) k=left ;;
      '') k=esc ;; *) continue ;;
    esac
  fi
  # Up and down move a whole card row in the grid, one prompt otherwise.
  step=1; [ "$full" -eq 0 ] && step=$ncol
  case "$k" in
    q) exit 0 ;;
    ' ') full=$((1 - full)) ;;
    up|k)           [ "$n" -gt 0 ] && sel=${queue[(idx + n * step - step) % n]%%|*} ;;
    down|j)         [ "$n" -gt 0 ] && sel=${queue[(idx + step) % n]%%|*} ;;
    left|h)         [ "$n" -gt 0 ] && sel=${queue[(idx + n - 1) % n]%%|*} ;;
    right|l|$'\t')  [ "$n" -gt 0 ] && sel=${queue[(idx + 1) % n]%%|*} ;;
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
