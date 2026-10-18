# claudebro_panes

A two-pane tmux layout for working with Claude Code: Claude runs in the top
pane, and the bottom pane is a plain shell that Claude can drive with
`send-keys` / `capture-pane`.

```
┌─ ◆ claude session ──────────────────────────────┐
│ Claude Code (~70% of the height)                │
│                                                 │
├─ ▸ commands — Claude drives this pane ──────────┤
│ $ plain shell                                   │
└─────────────────────────────────────────────────┘
```

## Install

Requires tmux 3.2+ (popups), `bash` or `zsh`, and `jq` for the Claude Code
hooks. The popups and picker use `lazygit`, `btop` and `fzf` if installed.

```sh
git clone git@github.com:plebeianchoo/claudebro_panes.git ~/claudebro/claudebro_panes
cd ~/claudebro/claudebro_panes
./install.sh
exec $SHELL -l
ta
```

`install.sh` appends a marked block to `~/.tmux.conf` and to your shell rc
(`~/.zshrc` for zsh, otherwise `~/.bashrc`), each sourcing a file from this
repo. It also asks whether to add `claude/USAGE.md` to `~/.claude/CLAUDE.md`,
so Claude Code knows it runs in the top pane and when (and how) to use the
bottom one. That block is a copy, not a link: after a `git pull`, re-run
`./install.sh` and answer `y` to refresh it. It then asks whether to add the
bell hooks (below) to `~/.claude/settings.json`, merging with any hooks
already there. It backs up anything it edits, is safe to re-run, and warns
if `ta` or `tn` is already defined elsewhere. `./uninstall.sh` removes everything it added.

Keep the clone where it is — the rc files source out of it by absolute path.

## Usage

    ta          # attach to session "main", creating the layout if absent
    ta foo      # same, for a session named "foo"
    tn foo      # alias for ta

An existing session is attached to untouched, so `ta` is also the reattach
command. Quitting Claude leaves a shell in the top pane rather than closing
it.

| Variable | Default | Meaning |
|---|---|---|
| `CLAUDEBRO_CMD` | `claude` | command run in the top pane |
| `CLAUDEBRO_SPLIT` | `30` | bottom pane height, percent |

Inside tmux, `ta` switches the current client instead of nesting a new one.

### Keys and clicks

| | |
|---|---|
| `Ctrl-b j` | fuzzy session picker (fzf): Enter switches; a new name + Enter creates it with the layout |
| `Ctrl-b g` | lazygit popup, in Nord, in the current pane's directory; outside a git repo, pick one of lazygit's recent repos instead (Esc closes) |
| `Ctrl-b b` | btop popup, in Nord |
| `Ctrl-b S` | throwaway shell popup |
| `Ctrl-b v` | markdown reader: fzf list of the `.md` files under the current directory with a rendered preview; click to highlight, double-click/Enter to read in glow (wheel/swipe scrolls, Shift-drag selects, q back to the list) |
| `Ctrl-b h` | tldr cheat sheets: fuzzy-search every page with a live preview; Enter for the full page. The `tmux` page also shows this setup's own keys and the most useful built-in ones, from `tldr/pages/tmux.patch.md` (`install.sh` links every page in `tldr/pages/` into tealdeer's custom pages; a `<name>.page.md` there would add a whole new page) |
| `Ctrl-b P` | canned prompts, for the tablet's on-screen keyboard: fzf over `prompts.txt` (or your own `~/.config/claudebro/prompts.txt`); Enter types the line into this window's Claude pane to edit or add to, Ctrl-S types and sends it, text matching no line is typed as is, Ctrl-E edits the list (starting your own copy) |
| `Ctrl-b A` | approvals popup: every Claude pane, in any session, sitting on a prompt you answer by choosing (permission, question, folder trust), as a grid of cards showing each prompt's first lines and options. Arrows (or `hjkl`, Tab) pick a card, `1`-`9` answers it, Esc cancels it, Space toggles between the cards and the selected prompt in full, Enter jumps to that pane, `q` closes. It re-reads the pane before sending and drops the key if the prompt has changed, and closes itself once you've answered the last one |
| `Ctrl-b T` | team popup: one block per Claude pane in every session (window, state, idle time, title topic, last 4 lines) plus the `## Assigned` section of `~/workbench/.team/BOARD.md`; read-only, refreshes every 2s, `q` closes. `shell/team-glance.sh --once` prints it once |
| `Ctrl-b C` | `team` window: a read-only live mirror pane per Claude pane (stacked, no shell panes), or switch to it if it exists; Enter in a mirror jumps to the real pane. Close it with `Ctrl-b &` |
| `●` / `○` after a window name | that window's Claude is working (`●`) or idle (`○`, its pane title starts with `✳`); no glyph for windows without Claude. The status bar refreshes every 3s |
| window names in the tabs | compact until there's an alert: the current window shows its name cut to 5 characters, a window whose Claude needs you (bell flagged) its full name, the others just number and `○`/`●` |
| narrow screens (a phone) | when even those tabs wouldn't fit the client's width (measured from the tabs, plus `@cb_status_reserve`, default 32 columns, for the session name's arrows and the right side) the bar goes compact: no flags, and alerted windows' names are cut to 5 characters too. `‹` `›` buttons appear at the start of the right side: tap them to scroll the window tabs a window at a time (tmux can't scroll its list, so tabs scrolled off draw as nothing; `shell/status-scroll.sh`). Switching windows resets the scroll. A wider client attached at the same time keeps the full bar |
| click session name (bottom left) | tmux's session list |
| click `+` (bottom right) | prompt for a name (blank for the default), open a new window in this session with the Claude + shell layout, in the current pane's directory |
| click `say` (bottom right) | the `Ctrl-b P` canned-prompts popup |
| click the orange `N waiting` chip | the `Ctrl-b A` approvals popup. The chip shows while any Claude is on a prompt (counted every 3s by `shell/approvals.sh --status`) |

Sessions created from a popup or button don't see `CLAUDEBRO_CMD` /
`CLAUDEBRO_SPLIT` from your shell rc, only tmux's own environment.

### Tablet keyboard

Hooks on client and window resizes (`shell/pin-layout.sh`) stop an on-screen
keyboard from pushing Claude's pane up. A keyboard shows up as the client
getting shorter at the same width, so for each width they remember the
tallest and shortest client seen. Once a width has a real drop, its windows
are pinned. Each pinned window keeps its keyboard-down size (manual, so tmux
no longer resizes it), and Claude's pane gets what fits with the keyboard up
(shortest - 2 borders - 1 shell row). When the keyboard comes up, tmux shows
the top of the window: all of Claude's pane and one shell row. The rest of
the shell sits under the keyboard. No pane is resized, so Claude doesn't move
or even redraw. Focusing the shell scrolls the view down to its cursor.

Resizing panes to compensate can't do this. When a pane ends up at the size
it started at, tmux replays the in-between size first to force a redraw, so
Claude flashes. That's why the window itself stays put.

The pin is only used when Claude keeps at least half its keyboard-down room
(`set -g @cb_pin_keep 50`, in percent). On the Pad Mini at 152x90 that pins
portrait (Claude 52 rows, shell 35 with 1 showing over the keyboard) and
leaves landscape (229x59, where Claude would keep only 24 of 56 rows) to
tmux. Desktops never shrink like this and are never pinned, and a client of
another width gets a pinned window back with the 30% shell. Only windows that
are exactly the two `ta` panes are touched. What it learns is saved to
`~/.local/state/claudebro/keyboard.conf` and loaded with this config. So only
the first keyboard at a new font size or orientation jumps, once.

### Theme

tmux is themed [Nord](https://www.nordtheme.com) by `tmux/nord.conf`: status
bar, pane borders, popups, menus and selection. It uses Nord's hex colours
directly, so it looks right whatever palette your terminal has (true colour
needed). To keep tmux's own colours instead, add `set -g @claudebro_theme
none` to `~/.tmux.conf` before the claudebro_panes block, and restart tmux.

The status bar uses the official Nord port's Powerline arrow segments
(U+E0B0–E0B3), which need a Powerline or Nerd Font in the terminal you
connect from. If they show as boxes or `?`, add `set -g
@claudebro_nord_glyphs off` there too for plain blocks (a reload is enough).

The btop popup runs Nord too, from its own config file
(`~/.config/btop/claudebro-popup.conf`, copied from your `btop.conf` on first
use), so running `btop` directly keeps your usual theme. Likewise the lazygit
popup loads your lazygit config with `lazygit/nord.yml` layered on top; a
plain `lazygit` is unchanged. glow (`glow/nord.json`, a recolour of glamour's
dark style, MIT), tldr (`tldr/nord.toml`) and the fzf pickers get Nord the
same way, only inside the popups.

### "Claude needs you" alerts

With the hooks installed, Claude Code runs `claude/bell.sh` when it finishes
a turn (`Stop`) or waits on a permission prompt (`Notification`). That rings
the bell in Claude's pane; tmux flags the window, and its tab turns orange
with a `!` until you visit it. Other sessions' alerts show in the session
picker (Ctrl-b j). No audible beep, and nothing for the window you're looking at.
A session another client is looking at counts as seen, so it won't flag.
Remove the hooks with `claude/hooks.sh uninstall` (or `./uninstall.sh`).

## How it works, and why

Three things in here are less obvious than they look:

- **Panes are addressed by id (`%N`), not by index.** Index addressing like
  `main:1.1` depends on `base-index` / `pane-base-index` being set to 1. On a
  machine with tmux defaults those panes are `main:0.0` and `main:0.1`, and
  index addressing would quietly target the wrong pane.
- **Claude starts from a `client-attached` hook, not immediately.** Launched
  in a still-detached session, Claude's background-colour query (OSC 11) has
  no terminal to answer it; the reply arrives only at attach, too late to be
  consumed, and gets drawn in the pane as literal `^[]11;rgb:2e2e/3434/4040`
  text. The hook unsets itself so reattaching doesn't start a second Claude.
- **Border labels key off a per-pane `@role` option, not the pane title.**
  Claude Code continuously rewrites its own pane title to the current
  conversation topic, so a title set with `select-pane -T` does not survive.

Note that `pane-border-status top` costs one row per pane, including in
single-pane windows.

## Layout

    shell/ta.sh              the ta() function and the tn alias
    shell/claudebro-session  ta for popups (the Ctrl-b j picker): create-or-switch a given client
    shell/claudebro-window   the + button: a new window with the Claude + shell layout (Claude not started)
    shell/pick-session.sh    the fzf session picker
    tmux/claudebro.conf      border labels, popups, status-bar buttons, alerts
    tmux/nord.conf           the Nord theme, loaded at the end of claudebro.conf
    shell/btop-popup.sh      btop for the popup, with its own config and the Nord theme
    btop/themes/nord.theme   btop's Nord theme (from aristocratos/btop v1.4.7, Apache-2.0)
    shell/lazygit-popup.sh   lazygit for the popup: your config + lazygit/nord.yml
    lazygit/nord.yml         lazygit colours in the Nord palette
    shell/glow-popup.sh      fzf markdown picker + glow reader for the Ctrl-b v popup
    glow/nord.json           glow (glamour) style in the Nord palette
    shell/team-glance.sh     the Ctrl-b T popup: every Claude pane at a glance, plus the team board
    shell/team-window.sh     the Ctrl-b C team window: creates or switches to it
    shell/team-mirror.sh     what runs in each team-window pane: a read-only mirror of one Claude pane
    shell/tldr-popup.sh      fzf over tldr pages for the Ctrl-b h popup
    shell/pin-layout.sh      window-resized hook: pins Claude's pane height on a tablet
    shell/prompts-popup.sh   the Ctrl-b P popup: types a canned prompt into Claude's pane
    prompts.txt              the default prompt list for it
    tldr/nord.toml           tealdeer colours in the Nord palette
    shell/popup-common.sh    shared by the launchers: true-colour check, Nord fzf colours
    claude/USAGE.md          tells Claude Code it's in the top pane, how to drive the bottom
    claude/bell.sh           Stop/Notification hook: bell in Claude's pane
    claude/hooks.sh          add/remove that hook in ~/.claude/settings.json
    install.sh / uninstall.sh
