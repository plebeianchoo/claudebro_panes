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
| `Ctrl-b g` | lazygit popup, in the current pane's directory |
| `Ctrl-b b` | btop popup |
| `Ctrl-b S` | throwaway shell popup |
| click session name (bottom left) | tmux's session list |
| click `+` (bottom right) | prompt for a name, create a new `ta` session |
| click `git` (bottom right) | lazygit popup |
| click an orange `name !` chip | picker, with that session at the top |

Sessions created from a popup or button don't see `CLAUDEBRO_CMD` /
`CLAUDEBRO_SPLIT` from your shell rc, only tmux's own environment.

### "Claude needs you" alerts

With the hooks installed, Claude Code runs `claude/bell.sh` when it finishes
a turn (`Stop`) or waits on a permission prompt (`Notification`). That rings
the bell in Claude's pane; tmux flags the window, and every session with a
flagged window shows as an orange `name !` chip at the bottom right until
you visit it. No audible beep, and nothing for the window you're looking at.
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
    shell/claudebro-session  ta for popups/buttons: create-or-switch a given client
    shell/pick-session.sh    the fzf session picker
    tmux/claudebro.conf      border labels, popups, status-bar buttons, alerts
    claude/USAGE.md          tells Claude Code it's in the top pane, how to drive the bottom
    claude/bell.sh           Stop/Notification hook: bell in Claude's pane
    claude/hooks.sh          add/remove that hook in ~/.claude/settings.json
    install.sh / uninstall.sh
