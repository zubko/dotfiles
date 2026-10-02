# dotfiles

## Layout

- `shared/<tool>/` holds the config for each tool. It is the same on every machine.
- `macos/` and `linux/` hold only OS-bound files. `install.sh` picks the right `zsh/zprofile` by `uname`.
- `install.sh` wires the home dotfiles to the repo files with a managed block, a git include and the nvim symlink.
- `sync.sh` pulls, shows the machine-only lines, then commits and pushes after a confirm.
- zsh details and the auto-reload rules are in `shared/zsh/CLAUDE.md`.

## Rules

- A new setting goes to `shared/`. Put it in `macos/` or `linux/` only when it cannot work on the other OS.
- Never edit the home dotfiles (`~/.zshrc`, `~/.tmux.conf`, ...) directly. Change the repo file, or change `install.sh` and run it.
- `install.sh` and `sync.sh` touch files outside the repo. Ask the user before running them.
- Test `install.sh` against a fixture home inside the repo, never against the real `$HOME`:

```
rm -rf .tmp; mkdir -p .tmp/home .tmp/bin
env -u ZSH -u ZDOTDIR -u ZSH_CUSTOM -u XDG_CONFIG_HOME -u GIT_CONFIG_GLOBAL \
  HOME="$PWD/.tmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" DOTFILES_SKIP_SYSTEM=1 ./install.sh
```

  `DOTFILES_SKIP_SYSTEM=1` skips package installs and `chsh`. `.tmp/` is gitignored. Fake binaries for the nvim cases go in `.tmp/bin`.
- Check a tmux config on a throwaway socket, never with a bare `tmux kill-server`:

```
S=.tmp/tmux.sock
tmux -S "$S" -f /dev/null start-server \; set -g exit-empty off
tmux -S "$S" source-file shared/tmux/tmux.conf; echo "rc=$?"
tmux -S "$S" kill-server; rm -f "$S"
```

- Lint scripts with `bash -n` and `shellcheck`, zsh files with `zsh -n`.
