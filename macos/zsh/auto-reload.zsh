# Auto-reload: re-source ~/.zshrc in live shells when a watched config file
# changes. Sourced from shared.zshrc. This file is not watched itself, so
# edits here need `exec zsh`.

zmodload -F zsh/stat b:zstat
autoload -Uz add-zsh-hook

typeset -gA _dotfiles_rc_seen

_dotfiles_rc_signature() {
  emulate -L zsh
  local -A st
  if zstat -H st -- "$1" 2>/dev/null; then
    REPLY="$st[mtime]:$st[size]:$st[inode]"
  else
    REPLY=missing
  fi
}

_dotfiles_rc_snapshot() {
  emulate -L zsh
  local f
  for f in "$_dotfiles_shared_rc" "$HOME/.zshrc"; do
    _dotfiles_rc_signature "$f"
    _dotfiles_rc_seen[$f]=$REPLY
  done
}

# No `emulate -L` here: it would localize any setopt made by the sourced files.
_dotfiles_rc_maybe_reload() {
  local f changed=0
  local -a files=("$_dotfiles_shared_rc" "$HOME/.zshrc")

  for f in $files; do
    _dotfiles_rc_signature "$f"
    [[ ${_dotfiles_rc_seen[$f]-} != "$REPLY" ]] && changed=1
  done
  (( changed )) || return 0

  for f in $files; do
    [[ ! -f $f ]] || command zsh -nf -- "$f" 2>/dev/null || {
      # remember the bad signature: retry after the next save, not on every command
      _dotfiles_rc_snapshot
      if zle 2>/dev/null; then
        zle -M "zsh config not reloaded: syntax error in $f"
      else
        print -u2 -- "zsh config not reloaded: syntax error in $f"
      fi
      return 0
    }
  done

  zle 2>/dev/null && zle -I
  # snapshot before sourcing to prevent re-entry
  _dotfiles_rc_snapshot
  builtin source "$HOME/.zshrc"
  print -u2 -- "⟳ zsh config reloaded"
}

# Runs on Enter before the line is parsed, so even alias changes
# apply to the command that triggered the reload.
_dotfiles_accept_line() {
  _dotfiles_rc_maybe_reload
  zle .accept-line
}

_dotfiles_rc_snapshot

if (( ! ${+_dotfiles_reload_installed} )); then
  typeset -g _dotfiles_reload_installed=1
  add-zsh-hook precmd _dotfiles_rc_maybe_reload
  zle -N accept-line _dotfiles_accept_line
fi
