# tmux session menu — git: ~/dotfiles/shared/zsh/tmux-menu.zsh
# Sourced from shared.zshrc, which runs `tm` once on SSH login. Run `tm` to see the menu again.

tm() {
  local -a lines
  local out choice name i
  # ':' as the separator: tmux turns a tab into '_' and does not allow ':' in session names
  out=$(tmux list-sessions -F '#{session_name}:#{session_windows} win#{?session_attached, attached,}' 2>&1) \
    && lines=(${(f)out})

  print "\ntmux sessions:"
  if (( $#lines )); then
    for (( i = 1; i <= $#lines; i++ )); do
      print -r -- "  $i) ${lines[i]%%:*}  [${lines[i]#*:}]"
    done
  elif [[ -n $out && $out != (no server running|error connecting to *\(No such file or directory\))* ]]; then
    print -r -- "  $out"
  else
    print "  (none)"
  fi
  print "  n) new session\n  q) quit"

  while read -r "choice?> "; do
    case $choice in
      <->)
        if (( choice >= 1 && choice <= $#lines )); then
          # without '=', a gone session would attach another session whose name starts the same
          tmux attach-session -t "=${lines[choice]%%:*}"
          return
        fi ;;
      n)
        read -r "name?Session name (blank = auto): " || return
        if [[ -n $name ]]; then tmux new-session -s "$name"; else tmux new-session; fi
        return ;;
      q|'') return ;;
    esac
    print "Invalid choice."
  done
}
