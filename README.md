# dotfiles

Config for zsh, tmux, git, vim and nvim. One repo for Macs, Debian Linux and Raspberry Pi.

## Layout

- `shared/` works on every machine: `shared/zsh`, `shared/tmux`, `shared/git`, `shared/vim`, `shared/nvim`.
- `macos/` and `linux/` hold only things that depend on the OS. Today that is `macos/zsh/zprofile` and `linux/zsh/zprofile`. `macos/.config` holds skhd, yabai and revdiff, applied with `macos/apply-configs.sh`.
- Rule: a new setting goes to `shared/` unless it only makes sense on one OS.

## New machine

```
git clone <repo> ~/dotfiles
~/dotfiles/install.sh
exec zsh
```

On Linux, log out and in once after the run. `chsh` changes the login shell, and the change applies to new logins only.

`install.sh` is safe to run again. Every run prints one line per file: `changed`, `already in place` or `skipped (...)`.

## What install.sh does in $HOME

- installs missing packages: zsh, tmux, git, vim, neovim, ripgrep, eza, fnm, and gcc on Linux. macOS uses brew. Linux uses apt, except neovim (GitHub release into `~/.local/opt/nvim`, apt is too old) and fnm (its own installer into `~/.local/bin`). It prints a hint when apt has no eza.
- sets the login shell to zsh when it is not zsh yet
- installs oh-my-zsh, three plugins and links the `alex` theme
- adds a managed block to `~/.zshrc`, `~/.zprofile`, `~/.tmux.conf` and `~/.vimrc`. The block holds one include line that points at the file in this repo.
- adds an `include.path` line to `~/.gitconfig`
- links `~/.config/nvim` to `shared/nvim` when nvim 0.10 or newer is installed
- makes a `.bak.<timestamp>` copy of every file it changes

Machine-only lines go above the managed block. In `~/.gitconfig` they go below the `[include]` section: git reads top to bottom and the last value wins.

## Existing machine after this layout change

```
cd ~/dotfiles && git pull && ./install.sh && exec zsh
```

The old file paths are gone, so a plain `git pull` leaves new shells without config until `install.sh` runs.

On a machine that had its own `~/.tmux.conf` or `~/.vimrc`, the old content stays above the new block. Compare it with the shared file once and delete it by hand. Same for the old `[user]` lines in `~/.gitconfig`.

## Daily sync

Edit the files in the repo. The other machines get the change with `git pull`.

`./sync.sh` does the full round: pull, show the machine-only lines of the home dotfiles, commit and push after one confirm.

Open zsh shells reload the config on their own, see `shared/zsh/CLAUDE.md`.

A running tmux needs a reload by hand:

```
tmux source-file ~/.tmux.conf
```

`prefix r` does the same, but it does not work in `tmux -CC` mode.
