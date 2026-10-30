#!/usr/bin/env bash
# Tests for `resurrect-hooks.sh save`: a throwaway tmux server, a fixture HOME with Claude session
# files, and a fixture save file. Fixtures go to .tmp/ (gitignored). The real tmux server is never touched.
cd "$(dirname "$0")/../.." || exit 1
R=$PWD
T=$R/.tmp/resurrect-save
# mkdir first: when the TMUX_TMPDIR dir is missing, tmux falls back to /tmp and the real server
rm -rf "$T"; mkdir -p "$T/home/.claude/sessions" "$T/resurrect"
S=$R/.tmp/tmux-$(id -u)/default
# $TMUX wins over TMUX_TMPDIR. SHELL=/bin/sh keeps the test panes off the real zsh config.
st() { env -u TMUX -u XDG_CONFIG_HOME -u XDG_DATA_HOME TMUX_TMPDIR="$R/.tmp" SHELL=/bin/sh HOME="$T/home" "$@"; }
kill_server() { st tmux -S "$S" kill-server 2>/dev/null; }
trap kill_server EXIT
kill_server

fail=0
ok() { echo "PASS $1"; }
ko() { echo "FAIL $1"; fail=1; }

# alpha:0.0 runs sleep as the pane process, alpha:0.1 runs sleep under sh, alpha:0.2 is a shell.
st tmux -f /dev/null new-session -d -s alpha -n w1 -c "$R" 'sleep 300'
st tmux split-window -t alpha:0 -c "$R" 'sh -c "sleep 300; :"'
st tmux split-window -t alpha:0 -c "$R"
st tmux new-session -d -s beta -c "$R" 'sleep 300'
st tmux new-session -d -s 'two words' -c "$R" 'sleep 300'
pane() { st tmux display-message -p -t "$1" "#{$2}"; }
A0=$(pane alpha:0.0 pane_id); A1=$(pane alpha:0.1 pane_id); A2=$(pane alpha:0.2 pane_id)
B0=$(pane beta:0.0 pane_id); W0=$(pane 'two words:0.0' pane_id)
A1_CHILD=$(pgrep -P "$(pane alpha:0.1 pane_pid)" | head -n 1)

session_file() { # name pid session-id tmux-place
  jq -n --arg pid "$2" --arg id "$3" --arg cwd "$R" --arg tmux "$4" \
    '{pid: ($pid | tonumber), sessionId: $id, cwd: $cwd} + (if $tmux == "" then {} else {tmux: $tmux} end)' \
    > "$T/home/.claude/sessions/$1.json"
}
session_file direct "$(pane alpha:0.0 pane_pid)" aaaaaaaa-0000-4000-8000-000000000001 "alpha:@0.$A0"
session_file child "$A1_CHILD" bbbbbbbb-0000-4000-8000-000000000002 "alpha:@0.$A1"
session_file foreign $$ cccccccc-0000-4000-8000-000000000003 "alpha:@0.$A2"
session_file badid "$(pane beta:0.0 pane_pid)" --dangerously-skip-permissions "beta:@1.$B0"
session_file spaces "$(pane 'two words:0.0' pane_pid)" dddddddd-0000-4000-8000-000000000004 "two words:@2.$W0"
session_file dead 99999999 eeeeeeee-0000-4000-8000-000000000005 "beta:@1.$B0"
session_file notmux $$ ffffffff-0000-4000-8000-000000000006 ""
printf 'not json' > "$T/home/.claude/sessions/broken.json"

t=$'\t'
line() { # session window pane-index command-name full-command
  echo "pane${t}$1${t}$2${t}1${t}:*${t}$3${t}✳ title${t}:$R${t}0${t}$4${t}:$5"
}
F=$T/resurrect/tmux_resurrect_test.txt
{
  line alpha 0 0 2.1.303 'claude'
  line alpha 0 1 2.1.303 'claude -c'
  line alpha 0 2 2.1.303 'claude -c'
  line beta 0 0 2.1.303 'claude --resume old-id'
  line 'two words' 0 0 2.1.303 'claude'
  line gamma 0 0 2.1.303 'claude Please adopt $(printf HELLO) "quoted"'
  line delta 0 0 2.1.303 'claude-foo'
  line delta 0 1 claude-tmux-sid ''
  line delta 0 2 zsh ''
  echo "window${t}alpha${t}0${t}:w1${t}1${t}:*${t}abcd,80x24,0,0{40x24,0,0,0,39x24,41,0,1}"
  echo "state${t}alpha${t}beta"
} > "$F"
ln -sfn "$F" "$T/resurrect/last"
{
  line alpha 0 0 2.1.303 'claude --resume aaaaaaaa-0000-4000-8000-000000000001' # the pane process itself
  line alpha 0 1 2.1.303 'claude --resume bbbbbbbb-0000-4000-8000-000000000002' # a child of the pane shell
  line alpha 0 2 2.1.303 'claude'                                               # a live pid outside the pane
  line beta 0 0 2.1.303 'claude'                                                # an id that is not a UUID
  line 'two words' 0 0 2.1.303 'claude --resume dddddddd-0000-4000-8000-000000000004'
  line gamma 0 0 2.1.303 'claude'                                               # no such pane: the prompt goes
  line delta 0 0 2.1.303 'claude-foo'
  line delta 0 1 claude-tmux-sid ''
  line delta 0 2 zsh ''
  echo "window${t}alpha${t}0${t}:w1${t}1${t}:*${t}abcd,80x24,0,0{40x24,0,0,0,39x24,41,0,1}"
  echo "state${t}alpha${t}beta"
} > "$T/expected.txt"

st "$R/shared/tmux/resurrect-hooks.sh" save "$F"; rc=$?
[ "$rc" = 0 ] && ok "exit 0" || ko "exit $rc"
if diff -u "$T/expected.txt" "$F"; then ok "rewrites the Claude panes as expected"; else ko "save file differs"; fi
[ "$(readlink "$T/resurrect/last")" = "$F" ] && ok "keeps the last symlink" || ko "last symlink changed"
[ "$(ls "$T/resurrect" | wc -l)" -eq 2 ] && ok "leaves no temp file" || ko "temp file left: $(ls "$T/resurrect")"

# A missing file is not an error: resurrect must not see a failed hook.
st "$R/shared/tmux/resurrect-hooks.sh" save "$T/none.txt"; rc=$?
[ "$rc" = 0 ] && ok "missing file: exit 0" || ko "missing file: exit $rc"

exit $fail
