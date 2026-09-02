# Shared zsh config (macOS) — git: ~/dotfiles/macos/zsh/shared.zshrc
# Sourced from ~/.zshrc. Machine-specific settings stay in ~/.zshrc itself.
# This file is re-sourced by auto-reload.zsh, from inside a function:
# top-level `typeset` must always use -g here.

typeset -g _dotfiles_shared_rc=${(%):-%N}

# --- oh-my-zsh (once per shell: omz is not safe to re-source) ---
if (( ! ${+_dotfiles_omz_loaded} )); then
  typeset -g _dotfiles_omz_loaded=1
  export ZSH="$HOME/.oh-my-zsh"
  ZSH_THEME="alex"
  plugins=(
    git
    zsh-autosuggestions
    history-substring-search
    zsh-syntax-highlighting
    zsh-npm-scripts-autocomplete
  )
  [ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"
fi

# --- locale & editor ---
export LANG=en_US.UTF-8
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='zed --wait'
fi

# --- completion / plugin styling ---
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=white'
zstyle ':completion:*' menu select

# --- PATH (portable) ---
# -U must also be on the scalars: on zsh 5.9, `export PATH="x:$PATH"` skips
# the dedupe when only the tied arrays are unique.
typeset -gU PATH path FPATH fpath
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# --- node / fnm (once per shell: each `fnm env` run creates a new multishell session) ---
if (( ! ${+_dotfiles_fnm_loaded} )) && command -v fnm >/dev/null; then
  typeset -g _dotfiles_fnm_loaded=1
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# --- bun ---
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# --- ls: eza short form with hidden files + Nerd Font icons; l == ls (falls back to plain ls) ---
if command -v eza >/dev/null; then
  alias ls='eza -a --icons=auto --group-directories-first'
  alias l='ls'
  alias lt='eza --tree --level=2 -a --icons=auto'
else
  alias ls='ls -a'
  alias l='ls'
fi

# --- aliases ---
alias python='python3'
alias pip='pip3'
alias p='pnpm'
alias n='npm'
alias y='yarn'
alias z='zed'
alias c='claude'

# --- functions ---

# `yarn start` fails with EADDRINUSE when a stale Metro packager holds the port.
yarn() {
  local a prev='' port='' dir=$PWD is_start=0
  for a in "$@"; do
    [[ $a == start || $a == start:* ]] && is_start=1
    [[ $a == --port=* ]] && port=${a#--port=}
    [[ $prev == --port ]] && port=$a
    [[ $a == --cwd=* ]] && dir=${a#--cwd=}
    [[ $prev == --cwd ]] && dir=$a
    prev=$a
  done
  if (( is_start )); then
    if [[ -z $port ]] && grep -q '"react-native":' "$dir/package.json" 2>/dev/null; then
      port=8081
    fi
    if [[ $port == <-> ]]; then
      local pids
      pids=$(lsof -ti tcp:$port -sTCP:LISTEN 2>/dev/null)
      if [[ -n $pids ]]; then
        print "[zsh] port $port is busy — killing PID(s): ${pids//$'\n'/ }"
        print -r -- "$pids" | xargs kill 2>/dev/null
        local i
        for i in {1..20}; do
          lsof -ti tcp:$port -sTCP:LISTEN >/dev/null 2>&1 || break
          sleep 0.1
        done
      fi
    fi
  fi
  command yarn "$@"
}

# --- Claude Code ---
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export CLAUDE_CODE_ENABLE_TODO_TOOLS=1
export DISABLE_TELEMETRY=1
export DO_NOT_TRACK=1

# --- auto-reload on config change ---
source "${_dotfiles_shared_rc:h}/auto-reload.zsh"
