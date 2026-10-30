#!/usr/bin/env bash
# Hooks for tmux-resurrect, set in tmux.conf.
#   save <file>    rewrites the command of each Claude pane in the save file: `claude --resume <id>` when
#                  a known Claude session runs there, a plain `claude` otherwise. The restore then brings
#                  the same session back into the same pane.
#   pre-restore    remembers the panes that exist before a restore, and closes the sidebar while it runs.
#   restore        kills the plain shells that stand where the sidebar panes were and opens the sidebar
#                  again. resurrect does not keep the pane option that marks a sidebar pane.
set -uo pipefail

PANES_OPTION="@resurrect-hooks-panes"
SIDEBAR_OPTION="@resurrect-hooks-sidebar"
UUID='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

# "window index, pane index, pane id, pane pid, session name", space separated. The name comes last
# because it may hold spaces. A tab would come out as _ from a client without a UTF-8 locale.
list_panes() {
  tmux list-panes -a -F '#{window_index} #{pane_index} #{pane_id} #{pane_pid} #{session_name}'
}

# True when process $1 is $2 or runs under it: Claude is the pane's own process, a child of its shell,
# or a bit deeper behind a wrapper.
runs_in() {
  local p="$1" i
  for i in 1 2 3 4 5; do
    [ "$p" = "$2" ] && return 0
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null || return 1
  done
  return 1
}

# One line per pane, "P <session> <window index> <pane index> <pane id>", then one line per Claude
# that runs in one of them, "S <pane id> <session id>". Tab separated. Claude writes its pid, session
# id and place ("session:@window.%pane") to ~/.claude/sessions/<pid>.json.
pane_sessions() {
  local panes line w p id name f pid sid place pane pane_pid
  panes="$(list_panes)"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    w="${line%% *}"; line="${line#* }"
    p="${line%% *}"; line="${line#* }"
    id="${line%% *}"; line="${line#* }"
    name="${line#* }"
    printf 'P\t%s\t%s\t%s\t%s\n' "$name" "$w" "$p" "$id"
  done <<<"$panes"
  for f in "$HOME"/.claude/sessions/*.json; do
    [ -f "$f" ] || continue
    IFS=$'\t' read -r pid sid place < <(jq -r 'select((.tmux // "") != "") | [.pid, .sessionId, .tmux] | @tsv' "$f" 2>/dev/null) || continue
    pane="${place##*.}"
    # The id ends up in a command typed into a shell: only Claude's own UUID form passes.
    [[ $pid =~ ^[0-9]+$ && $sid =~ $UUID && $pane =~ ^%[0-9]+$ ]] || continue
    # A record of a Claude that is gone, or one from another tmux server, names a pane it does not run in.
    pane_pid="$(awk -v id="$pane" '$3 == id { print $4; exit }' <<<"$panes")"
    { [ -n "$pane_pid" ] && runs_in "$pid" "$pane_pid"; } || continue
    printf 'S\t%s\t%s\n' "$pane" "$sid"
  done
}

save() {
  local file="${1:-}" tmp
  { [ -f "$file" ] && command -v jq >/dev/null; } || return 0
  tmp="$(mktemp "$file.XXXXXX")" || return 0
  # Save file lines start with pane, window, state or grouped_session, so P and S are free.
  # A Claude pane without a known session gets a plain `claude`: its saved command may hold a prompt,
  # which resurrect would type into a shell as it is.
  if { pane_sessions; cat "$file"; } | awk -F'\t' -v OFS='\t' '
    $1 == "P" { pane_of[$2 FS $3 FS $4] = $5; next }
    $1 == "S" { sid[$2] = $3; next }
    $1 == "pane" && $11 ~ /^:claude( |$)/ {
      key = $2 FS $3 FS $6
      cmd = ":claude"
      if ((key in pane_of) && (pane_of[key] in sid)) cmd = cmd " --resume " sid[pane_of[key]]
      out = $1
      for (i = 2; i <= 10; i++) out = out OFS $i
      print out, cmd
      next
    }
    { print }' > "$tmp"; then
    mv -f "$tmp" "$file" || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
}

# The same folder rule as resurrect's helpers.sh, including the three names it expands.
resurrect_dir() {
  local dir
  dir="$(tmux show -gqv @resurrect-dir)"
  if [ -n "$dir" ]; then
    dir="${dir//\$HOME/$HOME}"
    dir="${dir//\$HOSTNAME/$(hostname)}"
    dir="${dir//\~/$HOME}"
  elif [ -d "$HOME/.tmux/resurrect" ]; then
    dir="$HOME/.tmux/resurrect"
  else
    dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
  fi
  printf '%s\n' "$dir"
}

# The sidebar's toggle key binding holds the path of cts, so a moved plugin folder needs no change here.
cts_path() {
  local key
  key="$(tmux show -gqv @cts_toggle_key)"
  key="${key:-b}"
  key="${key%% *}"
  tmux list-keys -T prefix | awk -v key="$key" '
    ($2 == "-T" && $3 == "prefix" && $4 == key) || ($2 == "-r" && $3 == "-T" && $4 == "prefix" && $5 == key)' |
    sed -n "s/.*\"'\([^']*\)' toggle .*/\1/p" | head -n 1
}

cts() { # on | off
  local path
  path="$(cts_path)"
  if [ -x "$path" ]; then
    "$path" "$1" || true
  else
    tmux display-message "resurrect-hooks: cts not found, use the sidebar key by hand" 2>/dev/null || true
  fi
}

pre_restore() {
  tmux set -g "$PANES_OPTION" "$(tmux list-panes -a -F '#{pane_id}' | tr '\n' ' ')"
  # While the sidebar is on, its tmux hooks add a pane to each new window, which shifts the pane
  # indexes that the restore works with.
  if [ "$(tmux show -gqv @cts_enabled)" = on ]; then
    tmux set -g "$SIDEBAR_OPTION" on
    cts off
  fi
}

restore() {
  local file existing found=0 s w flags p id ids="" zoom=""
  file="$(resurrect_dir)/last"
  existing=" $(tmux show -gqv "$PANES_OPTION") "
  if [ -f "$file" ]; then
    # macOS cuts the process name at 15 characters, Linux does not.
    while IFS=$'\t' read -r s w flags p; do
      found=1
      # Killing the only pane of a window would close the window.
      [ "$(tmux display-message -p -t "$s:$w" '#{window_panes}' 2>/dev/null)" -gt 1 ] 2>/dev/null || continue
      id="$(tmux display-message -p -t "$s:$w.$p" '#{pane_id}' 2>/dev/null)" || continue
      # A pane from before the restore is not a restored shell. A pane with the option is a live sidebar.
      case "$existing" in *" $id "*) continue ;; esac
      [ "$(tmux display-message -p -t "$id" '#{@cts_sidebar}')" = 1 ] && continue
      ids="$ids$id"$'\n'
      # A kill unzooms the window. The zoom comes back once the sidebar is open again.
      case "$flags" in *Z*) zoom="$zoom$s:$w"$'\n' ;; esac
    done < <(awk -F'\t' '$1 == "pane" && $10 ~ /^claude-tmux-sid(ebar)?$/ { print $2 "\t" $3 "\t" $5 "\t" $6 }' "$file")
  fi
  # All ids first, then the kills: a kill shifts the pane indexes of its window.
  while read -r id; do
    [ -n "$id" ] && tmux kill-pane -t "$id"
  done <<<"$ids"
  if [ "$found" = 1 ] || [ "$(tmux show -gqv "$SIDEBAR_OPTION")" = on ]; then
    cts on
  fi
  while read -r w; do
    [ -n "$w" ] && tmux resize-pane -Z -t "$w"
  done <<<"$zoom"
  tmux set -gu "$PANES_OPTION"
  tmux set -gu "$SIDEBAR_OPTION"
}

case "${1:-}" in
  save) save "${2:-}" ;;
  pre-restore) pre_restore ;;
  restore) restore ;;
  *) echo "usage: ${0##*/} save <file> | pre-restore | restore" >&2; exit 1 ;;
esac
# A failed hook must not fail the save or the restore.
exit 0
