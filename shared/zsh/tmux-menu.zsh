# tmux session menu — git: ~/dotfiles/shared/zsh/tmux-menu.zsh
# Sourced from shared.zshrc, which runs `tm` once on SSH login. Run `tm` to see the menu again.

tm() {
  emulate -L zsh
  local -a lines
  local out choice name i key keys=qwertyuiop
  # ':' as the separator: tmux turns a tab into '_' and does not allow ':' in session names
  # newest attach first; `list-sessions -O` needs tmux 3.7
  out=$(tmux list-sessions -F '#{session_last_attached}:#{session_name}:#{session_windows} win#{?session_attached, attached,}' 2>&1) \
    && lines=(${(f)"$(sort -s -t: -k1,1nr <<<$out)"}) && lines=(${lines#*:})

  print "\ntmux sessions:"
  if (( $#lines )); then
    for (( i = 1; i <= $#lines; i++ )); do
      if (( i <= 10 )); then key="$(( i % 10 ))/${keys[i]}"; else key=$i; fi
      print -r -- "  $key) ${lines[i]%%:*}  [${lines[i]#*:}]"
    done
  elif [[ -n $out && $out != (no server running|error connecting to *\(No such file or directory\))* ]]; then
    print -r -- "  $out"
  else
    print "  (none)"
  fi
  print "  n) new session\n  x) quit"

  while read -r "choice?> "; do
    # phone keyboards may capitalize the first letter
    choice=${choice:l}
    case $choice in
      '') (( $#lines )) || return; choice=1 ;;
      0) choice=10 ;;
      [$keys]) choice=${keys[(i)$choice]} ;;
    esac
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
      x) return ;;
    esac
    print "Invalid choice."
  done
}
