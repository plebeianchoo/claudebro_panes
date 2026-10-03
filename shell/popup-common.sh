# popup-common.sh — shared by the popup launchers. Source, don't run.

# Programs only use exact hex colours when COLORTERM says the terminal can
# show them; otherwise they round Nord to the nearest of 256. Claim true
# colour only if the tmux client actually reports RGB support.
claudebro_truecolor() {
  if [ -z "${COLORTERM:-}" ] && [ -n "${TMUX:-}" ] &&
     tmux display -p '#{client_termfeatures}' 2>/dev/null | grep -q RGB; then
    export COLORTERM=truecolor
  fi
}

# fzf in the Nord palette (https://www.nordtheme.com).
CLAUDEBRO_FZF_NORD='--color=fg:#D8DEE9,bg:-1,hl:#88C0D0,fg+:#ECEFF4,bg+:#3B4252,hl+:#8FBCBB,info:#EBCB8B,prompt:#81A1C1,pointer:#88C0D0,marker:#A3BE8C,spinner:#B48EAD,header:#5E81AC,border:#4C566A,gutter:-1'
