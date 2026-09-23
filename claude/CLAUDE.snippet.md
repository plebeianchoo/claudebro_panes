Paste into `~/.claude/CLAUDE.md` so Claude Code knows about the layout.

```markdown
## tmux layout

- Sessions here default to running inside **tmux**, with a `main` session
  split into two stacked panes: **pane 1** (`main:1.1`) is the **top** pane
  (~70% of the height) and runs Claude Code itself (this session); **pane 2**
  (`main:1.2`) is the **bottom** pane, a separate plain terminal.
- To read output from something running in pane 2, or to run a command
  there and see what it produced, use `tmux send-keys -t main:1.2 "<cmd>"
  Enter` to run it and `tmux capture-pane -t main:1.2 -p` to read the
  pane's contents back. Check `tmux list-panes -a` first since pane
  indices can vary if the layout changes.
```

The `main:1.1` / `main:1.2` addresses assume `base-index 1` and
`pane-base-index 1`. Without those, the panes are `main:0.0` and `main:0.1`.
`tmux list-panes -a` shows the real addresses on any machine.
