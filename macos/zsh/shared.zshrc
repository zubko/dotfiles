# Shared zsh config (macOS) — git: ~/dotfiles/macos/zsh/shared.zshrc
# Sourced from ~/.zshrc. Machine-specific settings stay in ~/.zshrc itself.

# --- oh-my-zsh ---
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

# --- locale & editor ---
export LANG=en_US.UTF-8
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='zed'
fi

# --- completion / plugin styling ---
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=white'
zstyle ':completion:*' menu select

# --- PATH (portable) ---
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# --- node / fnm ---
command -v fnm >/dev/null && eval "$(fnm env --use-on-cd --shell zsh)"

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

# --- AI / telemetry opt-out ---
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1
export DISABLE_TELEMETRY=1
export DO_NOT_TRACK=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
