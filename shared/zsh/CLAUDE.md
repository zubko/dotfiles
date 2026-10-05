# Shared zsh config

## zsh config auto-reload

`shared/zsh/auto-reload.zsh` (sourced at the end of `shared/zsh/shared.zshrc`) watches `shared/zsh/shared.zshrc` and `~/.zshrc`. When one of them changes, every open shell re-sources `~/.zshrc` on its own. Two triggers:

- pressing Enter (an `accept-line` ZLE wrapper) — runs before the line is parsed, so even a new alias applies to that same command
- before each prompt (`precmd`) — catches changes made by commands like `git pull`

What hot-reloads: aliases, functions, exports, and PATH, in both files.

Limitations:

- The oh-my-zsh block and `fnm env` run once per shell. Changes to the plugin list, the theme, or fnm need `exec zsh`.
- `shared/zsh/auto-reload.zsh` is not watched. Edits to the engine itself need `exec zsh`.
- A removed alias/function/export stays defined until a fresh shell.
- A file with a syntax error is not sourced. The shell prints a warning and keeps the old config until the next save.

Rules for editing `shared/zsh/shared.zshrc`:

- Keep the oh-my-zsh, fnm and tmux menu blocks behind their run-once guards.
- Keep the tmux menu block last. A tmux server started from the menu copies the env as it is at that point.
- The file is re-sourced from inside a function. At top level use `typeset -g` or `export`, never plain `typeset`.
- Keep `typeset -gU PATH path FPATH fpath` above the PATH prepends. It dedupes PATH on every reload. The scalars must be listed too: on zsh 5.9, `export PATH="x:$PATH"` skips the dedupe when only the tied arrays are unique.

## tmux menu on SSH login

The last block of `shared/zsh/shared.zshrc` runs `tm` from `shared/zsh/tmux-menu.zsh` once per shell. It runs only in the login shell that sshd starts on the SSH tty.

- `$ZSH_ARGZERO` starts with `-` only in a login shell started by sshd or `login`. IDEs and scripts run `zsh -l`, which gives `/bin/zsh`, so they get no menu.
- `tm` runs tmux in the login shell itself, so job control works: `C-b C-z` suspends the client and `fg` brings it back.
