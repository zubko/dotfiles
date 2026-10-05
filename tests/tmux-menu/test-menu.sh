#!/usr/bin/env bash
# End-to-end tests for the tmux menu: a real `-zsh` login with SSH_TTY on its pty, a fixture
# ZDOTDIR and HOME, the repo's zprofile and shared.zshrc, and a throwaway tmux server.
# Fixtures go to .tmp/ (gitignored). The real tmux server is never touched.
cd "$(dirname "$0")/../.." || exit 1
R=$PWD
case $(uname) in Darwin) PLATFORM=macos ;; *) PLATFORM=linux ;; esac
ZSH_BIN=$(command -v zsh)
TM=$(command -v tmux)
# mkdir first: when the TMUX_TMPDIR dir is missing, tmux falls back to /tmp and the real server
mkdir -p .tmp/home .tmp/zdot .tmp/zdot-off .tmp/bad
rm -f .tmp/home/.zshrc
S=$R/.tmp/tmux-$(id -u)/default
printf 'source %q\n' "$R/$PLATFORM/zsh/zprofile" | tee .tmp/zdot/.zprofile > .tmp/zdot-off/.zprofile
printf "PS1='PROMPT> '\nsource %q\n" "$R/shared/zsh/shared.zshrc" > .tmp/zdot/.zshrc
printf "DOTFILES_TMUX_MENU=0\nPS1='PROMPT> '\nsource %q\n" "$R/shared/zsh/shared.zshrc" > .tmp/zdot-off/.zshrc

# $TMUX wins over TMUX_TMPDIR. SHELL=/bin/sh keeps the test panes off the real zsh config.
st() { env -u TMUX -u XDG_CONFIG_HOME -u SSH_TTY -u DOTFILES_TMUX_MENU TMUX_TMPDIR="$R/.tmp" SHELL=/bin/sh \
  HOME="$R/.tmp/home" ZDOTDIR="$R/.tmp/zdot" PATH=/usr/bin:/bin "$@"; }
login() { st python3 tests/tmux-menu/drive.py --argv0=-zsh --ssh-tty "$@" -- "$ZSH_BIN"; }
kill_server() { st "$TM" -S "$S" kill-server 2>/dev/null; }
trap kill_server EXIT
NOLANG=(--unset LANG --unset LC_ALL --unset LC_CTYPE)

fail=0
check() { # name output regex...  (a regex that starts with ! must not match)
  local name=$1 out=$2 rx bad=0; shift 2
  for rx in "$@"; do
    if [[ $rx == !* ]]; then grep -qE -- "${rx#!}" <<<"$out" && { echo "  matched: ${rx#!}"; bad=1; }
    else grep -qE -- "$rx" <<<"$out" || { echo "  missing: $rx"; bad=1; }; fi
  done
  if (( bad )); then echo "FAIL $name"; echo "    | ${out//$'\n'/$'\n'    | }"; fail=1; else echo "PASS $name"; fi
}
menus() { grep -c '^tmux sessions:$' <<<"$1"; }

kill_server

# --- no server: the menu starts it with the final env, even when the client sends no locale ---
out=$(login "${NOLANG[@]}" --step 'expect:\(none\)' --step 'expect:> ' --step 'send:n\r' \
  --step 'expect:Session name' --step 'send:fresh\r' --step 'expect:\[fresh\]' --step 'send:\x02d' \
  --step 'expect:detached' --step 'expect:PROMPT> ' --step 'send:tmux show-environment -g LANG\r' \
  --step 'expect:LANG=en_US.UTF-8' --step 'send:tmux show-environment -g PATH\r' \
  --step 'expect:PATH=.*\.tmp/home/\.local/bin' --step 'send:exit 0\r' --step eof)
check 'no server: n starts tmux with the final env' "$out" '^EXIT=0$'
kill_server

# --- a tmux error other than "no server" is shown ---
mkdir -p ".tmp/bad/tmux-$(id -u)" && chmod 777 ".tmp/bad/tmux-$(id -u)"
out=$(login --env "TMUX_TMPDIR=$R/.tmp/bad" --step 'expect:unsafe permissions' --step 'expect:> ' \
  --step 'send:q\r' --step 'expect:PROMPT> ' --step 'send:exit 0\r' --step eof)
check 'a tmux error is shown, not (none)' "$out" '^EXIT=0$' '!\(none\)'

# --- throwaway server ---
st "$TM" -S "$S" -u -f /dev/null new-session -d -s work
st "$TM" -S "$S" -u new-window -d -t 'work:'
st "$TM" -S "$S" -u new-session -d -s 'my notes'
st "$TM" -S "$S" -u new-session -d -s 'café'
sockets=$(st "$TM" list-sessions -F '#{socket_path}' | sort -u)
if [[ $sockets != "$S" ]]; then echo "STOP: socket check failed: $sockets"; exit 1; fi
echo "PASS socket check: $sockets"

out=$(login --step 'expect:3\) work  \[2 win\]' --step 'expect:> ' --step 'send:3\r' --step 'expect:\[work\]' \
  --step 'send:\x02\x1a' --step 'expect:suspended' --step 'expect:PROMPT> ' --step 'send:fg\r' \
  --step 'expect:continued' --step 'expect:\[work\]' --step 'send:\x02d' \
  --step 'expect:detached \(from session work\)' --step 'expect:PROMPT> ' --step 'send:tm\r' \
  --step 'expect:tmux sessions:' --step 'expect:> ' --step 'send:q\r' --step 'expect:PROMPT> ' \
  --step 'send:exit 0\r' --step eof)
check 'attach, C-b C-z, fg, detach to a prompt, tm, q' "$out" '^EXIT=0$' '^  1\) café  \[1 win\]$' '^  2\) my notes  \[1 win\]$'
[[ $(menus "$out") == 2 ]] || { echo "FAIL want 2 menus (login + tm), got $(menus "$out")"; fail=1; }

for key in 'q\r' '\r' '\x03' '\x04'; do
  # shellcheck disable=SC2016  # the print line runs in the test shell, not here
  out=$(login --step 'expect:> ' --step "send:$key" --step 'expect:PROMPT> ' \
    --step 'send:print -r -- "E=$EDITOR L=$LANG W=$(whence -w tm) H=${precmd_functions[(r)_dotfiles_rc_maybe_reload]}"\r' \
    --step 'expect:E=.+ L=en_US.UTF-8 W=tm: function H=_dotfiles_rc_maybe_reload' --step 'send:exit 0\r' --step eof)
  check "key $key quits the menu to a shell with the full config" "$out" '^EXIT=0$'
done

out=$(login --step 'expect:> ' --step 'send:x\r' --step 'expect:Invalid choice' --step 'send:9\r' \
  --step 'expect:Invalid choice' --step 'send:0\r' --step 'expect:Invalid choice' --step 'send:q\r' \
  --step 'expect:PROMPT> ' --step 'send:exit 0\r' --step eof)
check 'invalid choices ask again' "$out" '^EXIT=0$'

out=$(login --step 'expect:> ' --step 'send:n\r' --step 'expect:Session name' --step 'send:work\r' \
  --step 'expect:duplicate session: work' --step 'expect:PROMPT> ' --step 'send:exit 0\r' --step eof)
check 'n with a duplicate name' "$out" '^EXIT=0$'

for key in 'abc\x03' '\x04'; do
  out=$(login --step 'expect:> ' --step 'send:n\r' --step 'expect:Session name' --step "send:$key" \
    --step 'expect:PROMPT> ' --step 'send:tmux ls -F "#S" | tr "\\n" " "; echo\r' --step 'expect:work' \
    --step 'send:exit 0\r' --step eof)
  check "key $key at the name prompt creates nothing" "$out" '^EXIT=0$' '!abc '
done

out=$(login --step 'expect:> ' --step 'send:n\r' --step 'expect:Session name' --step 'send:\r' \
  --step 'expect:\[[0-9]+\]' --step 'send:\x02d' --step 'expect:detached' --step 'expect:PROMPT> ' \
  --step 'send:exit 0\r' --step eof)
check 'n with a blank name gets an auto name' "$out" '^EXIT=0$'
st "$TM" -S "$S" list-sessions -F '#S' | grep -E '^[0-9]+$' | while read -r n; do st "$TM" -S "$S" kill-session -t "=$n"; done

out=$(login "${NOLANG[@]}" --step 'expect:1\) café' --step 'expect:> ' --step 'send:1\r' --step 'expect:\[café\]' \
  --step 'send:\x02d' --step 'expect:detached' --step 'expect:PROMPT> ' --step 'send:exit 0\r' --step eof)
check 'UTF-8 when the client sends no locale' "$out" '^EXIT=0$' '!caf_'

out=$(login --env TERM=xterm-bogus --step 'expect:unsuitable terminal: xterm-bogus' --step 'expect:> ' \
  --step 'send:q\r' --step 'expect:PROMPT> ' --step 'send:exit 0\r' --step eof)
check 'unknown TERM: the menu shows the tmux error' "$out" '^EXIT=0$' '!\(none\)'

out=$(login --step 'expect:> ' --step 'send:q\r' --step 'expect:PROMPT> ' \
  --step "run:cp '$R/.tmp/zdot/.zshrc' '$R/.tmp/home/.zshrc'" --step 'send:\r' \
  --step 'expect:zsh config reloaded' --step 'expect:PROMPT> ' --step 'send:exit 0\r' --step eof)
check 'auto-reload does not show the menu again' "$out" '^EXIT=0$'
[[ $(menus "$out") == 1 ]] || { echo "FAIL auto-reload: want 1 menu, got $(menus "$out")"; fail=1; }
rm -f .tmp/home/.zshrc

out=$(st python3 tests/tmux-menu/drive.py --ssh-tty --step 'expect:PROMPT> ' --step 'send:exit 0\r' --step eof -- "$ZSH_BIN" -l)
check 'zsh -l (IDE, script): no menu' "$out" '^EXIT=0$' '!tmux sessions:'

out=$(login --env "ZDOTDIR=$R/.tmp/zdot-off" --step 'expect:PROMPT> ' --step 'send:exit 0\r' --step eof)
check 'DOTFILES_TMUX_MENU=0 above the block in ~/.zshrc' "$out" '^EXIT=0$' '!tmux sessions:'

out=$(login --step 'expect:3\) work' --step 'expect:> ' --step "run:'$TM' -S '$S' kill-session -t =work" \
  --step 'send:3\r' --step "expect:can't find session" --step 'expect:PROMPT> ' --step 'send:exit 0\r' --step eof)
check 'a session that is gone' "$out" '^EXIT=0$'

exit $fail
