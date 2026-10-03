- claudebro: fuzzy session picker (Enter switches; a new name creates a session):

`<Ctrl b><j>`

- claudebro: popups for lazygit, btop, a throwaway shell, the markdown reader, and these cheat sheets:

`<Ctrl b><g>, <b>, <S>, <v>, <h>`

- Rename the current session / window:

`<Ctrl b><$> / <Ctrl b><,>`

- Pick any session or window from a tree:

`<Ctrl b><s> / <Ctrl b><w>`

- Go to the next / previous window, or window 1-9 (numbered from 1 here):

`<Ctrl b><n> / <p> / <1>…<9>`

- Kill the current window (asks first):

`<Ctrl b><&>`

- Split side by side / top and bottom, keeping the current directory (your bindings):

`<Ctrl b><|> / <Ctrl b><->`

- Move to another pane (or click it: the mouse is on):

`<Ctrl b><ArrowKeys>`

- Show pane numbers, then press one to jump to it:

`<Ctrl b><q>`

- Zoom the current pane to the whole window, and back:

`<Ctrl b><z>`

- Resize the current pane by 1 cell / by 5 (hold the second key and repeat):

`<Ctrl b><Ctrl ArrowKeys> / <Ctrl b><Alt ArrowKeys>`

- Swap the pane with the previous / next one, or cycle through layouts:

`<Ctrl b><{> / <}> / <Space>`

- Move the current pane into a window of its own:

`<Ctrl b><!>`

- Kill the current pane (asks first):

`<Ctrl b><x>`

- Scroll back / copy mode (or just scroll the mouse wheel); `<q>` leaves:

`<Ctrl b><[>`

- In copy mode (emacs keys): search back / forward, start a selection, copy it:

`<Ctrl r> / <Ctrl s> / <Ctrl Space> / <Alt w>`

- Copy with the mouse: drag to select (copies on release); hold Shift for the terminal's own selection:

`<Drag> / <Shift Drag>`

- Paste what tmux copied last:

`<Ctrl b><]>`

- Open the tmux command prompt, or list every key binding:

`<Ctrl b><:> / <Ctrl b><?>`

- Reload ~/.tmux.conf (your binding):

`<Ctrl b><r>`

- Send Ctrl b through to a tmux nested inside this one:

`<Ctrl b><Ctrl b>`

- Run a command in another pane, then read what it printed:

`tmux send-keys -t {{main:1.2}} "{{command}}" Enter && tmux capture-pane -t {{main:1.2}} -p`

- Rename a session from the shell:

`tmux rename-session -t {{old_name}} {{new_name}}`

- Kill every session (the whole tmux server):

`tmux kill-server`
