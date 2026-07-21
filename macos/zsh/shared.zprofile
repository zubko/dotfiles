# Shared zsh login config (macOS) — git: ~/dotfiles/macos/zsh/shared.zprofile
# Sourced from ~/.zprofile. Machine-specific PATHs stay in ~/.zprofile.

# --- homebrew (Apple Silicon) ---
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv zsh)"

# --- pnpm ---
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# --- rust / cargo ---
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
