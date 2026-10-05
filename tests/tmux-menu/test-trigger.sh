#!/usr/bin/env bash
# Trigger tests for the last block of shared/zsh/shared.zshrc, with a fake menu and a fake tmux.
# Fixtures go to .tmp/ (gitignored).
cd "$(dirname "$0")/../.." || exit 1
R=$PWD
T=$R/.tmp/t
ZSH_BIN=$(command -v zsh)
rm -rf "$T" .tmp/bin .tmp/empty .tmp/thome
mkdir -p "$T/shared/zsh" .tmp/bin .tmp/empty .tmp/thome
cp shared/zsh/shared.zshrc shared/zsh/auto-reload.zsh "$T/shared/zsh/"
printf 'tm() { print MENU }\n' > "$T/shared/zsh/tmux-menu.zsh"
printf '#!/bin/sh\nexit 0\n' > .tmp/bin/tmux
chmod +x .tmp/bin/tmux

fail=0
run() { # name want(MENU|NO_MENU) argv0 pathdir script-before
  local name=$1 want=$2 argv0=$3 pathdir=$4 pre=$5 out n
  # shared.zshrc is sourced twice: the second time stands for an auto-reload
  out=$(env -u SSH_TTY -u TMUX -u DOTFILES_TMUX_MENU python3 tests/tmux-menu/drive.py \
    --env "PATH=$pathdir" --env "HOME=$R/.tmp/thome" "--argv0=$argv0" --ssh-tty --step eof \
    -- "$ZSH_BIN" -f -i -c "$pre; source $T/shared/zsh/shared.zshrc; source $T/shared/zsh/shared.zshrc; echo AFTER")
  n=$(grep -c '^MENU$' <<<"$out")
  if [[ $want == MENU && $n == 1 ]] || [[ $want == NO_MENU && $n == 0 ]]; then
    if grep -q '^AFTER$' <<<"$out" && grep -q '^EXIT=0$' <<<"$out"; then echo "PASS $name"; return; fi
  fi
  echo "FAIL $name (menus=$n, want $want)"; echo "    | ${out//$'\n'/$'\n'    | }"; fail=1
}

B=$R/.tmp/bin
run 'sshd login shell: menu once, also after a re-source' MENU    -zsh "$B" ':'
run 'DOTFILES_TMUX_MENU empty: menu'                      MENU    -zsh "$B" 'DOTFILES_TMUX_MENU='
run 'zsh -l (IDE, script): no menu'                       NO_MENU zsh  "$B" ':'
run 'SSH_TTY empty'                                       NO_MENU -zsh "$B" 'SSH_TTY='
run 'SSH_TTY other tty'                                   NO_MENU -zsh "$B" 'SSH_TTY=/dev/ttys999'
run 'inside tmux'                                         NO_MENU -zsh "$B" 'TMUX=x'
run 'DOTFILES_TMUX_MENU=0'                                NO_MENU -zsh "$B" 'DOTFILES_TMUX_MENU=0'
run 'TERM=dumb (Emacs TRAMP)'                             NO_MENU -zsh "$B" 'TERM=dumb'
run 'no tmux on PATH'                                     NO_MENU -zsh "$R/.tmp/empty" ':'

exit $fail
