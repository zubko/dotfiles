#!/usr/bin/env bash
# Tests for `resurrect-hooks.sh pre-restore` and `restore`: a throwaway tmux server with a plain shell
# where a sidebar pane was, a fixture save file, and a fake cts bound to the toggle key. Fixtures go to
# .tmp/ (gitignored). The real tmux server is never touched.
cd "$(dirname "$0")/../.." || exit 1
R=$PWD
T=$R/.tmp/resurrect-restore
# mkdir first: when the TMUX_TMPDIR dir is missing, tmux falls back to /tmp and the real server
rm -rf "$T"; mkdir -p "$T/home/resurrect" "$T/bin"
S=$R/.tmp/tmux-$(id -u)/default
# $TMUX wins over TMUX_TMPDIR. SHELL=/bin/sh keeps the test panes off the real zsh config.
st() { env -u TMUX -u XDG_CONFIG_HOME -u XDG_DATA_HOME TMUX_TMPDIR="$R/.tmp" SHELL=/bin/sh HOME="$T/home" "$@"; }
kill_server() { st tmux -S "$S" kill-server 2>/dev/null; }
trap kill_server EXIT
# The fake cts logs its argument. `on` adds a pane to every window, like the real sidebar does.
cat > "$T/bin/cts" <<FAKE
#!/bin/sh
echo "\$*" >> "$T/cts.log"
[ "\$1" = on ] && tmux list-windows -a -F '#{window_id}' | while read -r w; do tmux split-window -d -h -t "\$w" -c /; done
exit 0
FAKE
chmod +x "$T/bin/cts"

fail=0
ok() { echo "PASS $1"; }
ko() { echo "FAIL $1"; fail=1; }

# alpha:0 has the shell that was a sidebar (pane 0) and a real pane (pane 1); alpha:1 has one pane.
# @resurrect-dir uses ~ on purpose: the script must expand it like resurrect does.
setup() {
  kill_server
  st tmux -f /dev/null new-session -d -s alpha -n w1 -c "$R"
  st tmux split-window -h -t alpha:0 -c "$R"
  st tmux new-window -t alpha:1 -c "$R"
  st tmux set -g @resurrect-dir '~/resurrect'
  st tmux set -g @cts_toggle_key 'x C-b'
  st tmux bind-key x run-shell -b "'$T/bin/cts' toggle '#{pane_id}'"
  rm -f "$T/cts.log" "$T/home/resurrect/last" "$T/home/resurrect/tmux_resurrect_test.txt"
}
save_file() { # lines...
  printf '%s\n' "$@" > "$T/home/resurrect/tmux_resurrect_test.txt"
  ln -sfn "$T/home/resurrect/tmux_resurrect_test.txt" "$T/home/resurrect/last"
}
win() { st tmux display-message -p -t "$1" "#{$2}"; }
hooks() { st "$R/shared/tmux/resurrect-hooks.sh" "$@"; }
log() { tr '\n' ' ' < "$T/cts.log" 2>/dev/null; }

t=$'\t'
line() { # session window flags pane-index command-name
  echo "pane${t}$1${t}$2${t}1${t}:$3${t}$4${t}title${t}:$R${t}0${t}$5${t}:"
}
SIDEBAR_A=$(line alpha 0 '*' 0 claude-tmux-sid)
SIDEBAR_A_ZOOMED=$(line alpha 0 '*Z' 0 claude-tmux-sid)
SIDEBAR_A_LINUX=$(line alpha 0 '*' 0 claude-tmux-sidebar)
CLAUDE_A="pane${t}alpha${t}0${t}1${t}:*${t}1${t}✳ x${t}:$R${t}1${t}2.1.303${t}:claude --resume aaaa"
SIDEBAR_B=$(line alpha 1 '' 0 claude-tmux-sid)
SIDEBAR_Z=$(line zeta 0 '*' 0 claude-tmux-sid)

echo "# sidebar shells go, the only pane of a window stays, cts on runs once, the zoom comes back"
setup
keep=$(win alpha:0.1 pane_id)
st tmux resize-pane -Z -t alpha:0.1
save_file "$SIDEBAR_A_ZOOMED" "$CLAUDE_A" "$SIDEBAR_B" "$SIDEBAR_Z"
hooks restore; rc=$?
[ "$rc" = 0 ] && ok "exit 0" || ko "exit $rc"
[ "$(win alpha:0 window_panes)" = 2 ] && st tmux list-panes -t alpha:0 -F "#{pane_id}" | grep -qx "$keep" && ok "kills the sidebar shell, keeps the Claude pane, gets a new sidebar" || ko "alpha:0 panes: $(st tmux list-panes -t alpha:0 -F '#{pane_id}' | tr '\n' ' ')"
[ "$(win alpha:1 window_panes)" = 2 ] && ok "keeps the only pane of a window" || ko "alpha:1 has $(win alpha:1 window_panes) panes"
[ "$(log)" = "on " ] && ok "runs cts on once, found through the toggle key" || ko "cts.log: $(log)"
[ "$(win alpha:0 window_zoomed_flag)" = 1 ] && [ "$(win alpha:0 pane_id)" = "$keep" ] && ok "zooms the Claude pane again" || ko "zoom flag $(win alpha:0 window_zoomed_flag), active $(win alpha:0 pane_id)"

echo "# the Linux process name is recognized too"
setup
save_file "$SIDEBAR_A_LINUX" "$CLAUDE_A"
hooks restore
[ "$(win alpha:0 window_panes)" = 2 ] && [ "$(log)" = "on " ] && ok "kills the sidebar shell and runs cts on" || ko "alpha:0 has $(win alpha:0 window_panes) panes, cts.log: $(log)"

echo "# no sidebar pane in the save file: nothing happens"
setup
save_file "$CLAUDE_A"
hooks restore; rc=$?
[ "$rc" = 0 ] && ok "exit 0" || ko "exit $rc"
[ "$(win alpha:0 window_panes)" = 2 ] && ok "kills nothing" || ko "alpha:0 has $(win alpha:0 window_panes) panes"
[ ! -e "$T/cts.log" ] && ok "does not run cts" || ko "cts ran: $(log)"

echo "# no save file: nothing happens"
setup
hooks restore; rc=$?
[ "$rc" = 0 ] && ok "exit 0" || ko "exit $rc"
[ "$(win alpha:0 window_panes)" = 2 ] && ok "kills nothing" || ko "alpha:0 has $(win alpha:0 window_panes) panes"
[ ! -e "$T/cts.log" ] && ok "does not run cts" || ko "cts ran: $(log)"

echo "# no toggle key binding: the shells still go, cts is skipped"
setup
st tmux unbind-key x
save_file "$SIDEBAR_A" "$CLAUDE_A"
hooks restore; rc=$?
[ "$rc" = 0 ] && ok "exit 0" || ko "exit $rc"
[ "$(win alpha:0 window_panes)" = 1 ] && ok "kills the sidebar shell" || ko "alpha:0 has $(win alpha:0 window_panes) panes"
[ ! -e "$T/cts.log" ] && ok "does not run cts" || ko "cts ran: $(log)"

echo "# a restore into a running server: panes from before the restore stay"
setup
hooks pre-restore
save_file "$SIDEBAR_A" "$CLAUDE_A"
hooks restore; rc=$?
[ "$rc" = 0 ] && ok "exit 0" || ko "exit $rc"
[ "$(win alpha:0 window_panes)" = 3 ] && ok "kills nothing, opens the sidebar" || ko "alpha:0 has $(win alpha:0 window_panes) panes"
[ -z "$(st tmux show -gqv @resurrect-hooks-panes)" ] && ok "forgets the pane list" || ko "pane list kept"

echo "# the sidebar was on before the restore: closed before, open after"
setup
st tmux set -g @cts_enabled on
hooks pre-restore
[ "$(log)" = "off " ] && ok "closes the sidebar first" || ko "cts.log: $(log)"
save_file "$CLAUDE_A"
hooks restore
[ "$(log)" = "off on " ] && ok "opens it again without sidebar lines" || ko "cts.log: $(log)"
[ -z "$(st tmux show -gqv @resurrect-hooks-sidebar)" ] && ok "forgets the sidebar state" || ko "sidebar state kept"

echo "# a live sidebar pane is never killed"
setup
st tmux set -p -t alpha:0.0 @cts_sidebar 1
save_file "$SIDEBAR_A" "$CLAUDE_A"
hooks restore
[ "$(win alpha:0 window_panes)" = 3 ] && ok "keeps the pane with the sidebar option" || ko "alpha:0 has $(win alpha:0 window_panes) panes"

exit $fail
