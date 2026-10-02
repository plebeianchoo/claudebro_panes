# Using claudebro_panes from inside Claude Code

This file is written to be read by Claude Code itself — paste it (or a link
to it) into `~/.claude/CLAUDE.md`, or let `install.sh` offer to do that for
you. It tells Claude what the two-pane layout means and how to use the
second pane.

## Your identity in this layout

If you are Claude Code and this layout is active, **you are running in the
top pane**. The bottom pane is a separate plain shell — it is not another
copy of you, and nothing runs there unless you (or the user) put it there.

**Run your own commands with your own shell tool, as usual** — not in the
bottom pane. Typing commands into a pane and reading the screen back is
slower, loses exit codes, and truncates output.

Use the bottom pane only when:

- the user asks you to run something there, or to read what's in it;
- the user should be able to watch it — a dev server, a log tail, a
  long-running build or test watcher;
- it's interactive or needs a real TTY (a REPL, a prompt, `sudo`), which
  your shell tool can't provide.

## Finding the bottom pane

Don't assume an address like `main:1.2` — pane indices depend on
`base-index` / `pane-base-index`, which vary by machine, and change if the
window layout changes. Instead, look up the pane tagged by role:

```sh
tmux list-panes -a -F '#{pane_id} #{@role}'
```

The pane with `@role` = `commands` is the one to drive; `@role` = `claude`
is you. If neither is set (an older session, or one built without this
repo's `ta`), fall back to `tmux list-panes -a -F '#{pane_id} #{pane_current_command}'`
and pick the pane that is *not* running `claude`.

## Driving it

```sh
tmux send-keys -t <pane_id> '<command>' Enter
tmux capture-pane -t <pane_id> -p
```

`send-keys` runs the command; `capture-pane -p` prints the pane's current
screen back to you as text. For a long-running command, wait a moment (or
poll) before capturing, since `capture-pane` reads whatever is on screen at
that instant, not a completed result.

## Things to know

- Claude Code runs on the alternate screen with no scrollback (`alt=1`,
  `history_size=0` in tmux terms), so you cannot inspect your own pane's
  history this way — only the bottom pane's.
- Claude Code rewrites its own pane title continuously to the current
  conversation topic. Don't use `#{pane_title}` to identify which pane is
  which — use `@role` as above.
- A shell that was already running before this repo was installed or
  updated keeps whatever `ta` definition it loaded at startup; it will not
  pick up changes to `~/.bashrc`/`~/.zshrc` until it is restarted (a new
  terminal, a new SSH connection, or `exec $SHELL -l`). A session built by a
  stale `ta` may be missing `@role` even though the installed files are
  current — that's why the fallback above exists.
