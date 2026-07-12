#!/usr/bin/env bash
# Set up zsh on this macOS machine: oh-my-zsh, plugins, the 'alex' theme, and
# the "source shared config" import lines in ~/.zshrc / ~/.zprofile.
# Safe to re-run.
set -euo pipefail

# Repo dir = wherever this script lives (<clone>/macos/zsh), so the dotfiles clone
# can sit anywhere: ~/dotfiles, ~/private/dotfiles, ...
ZDIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
OMZ="$HOME/.oh-my-zsh"
CUSTOM="${ZSH_CUSTOM:-$OMZ/custom}"
TS="$(date +%Y%m%d_%H%M%S)"

[ "$(uname)" = "Darwin" ] || { echo "macOS only"; exit 1; }
[ -f "$ZDIR/shared.zshrc" ] || { echo "install.sh must live in the dotfiles macos/zsh/ dir"; exit 1; }

# 1. oh-my-zsh  (--keep-zshrc: do NOT let the installer overwrite ~/.zshrc)
if [ ! -d "$OMZ" ]; then
  echo "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

# 2. brew deps
command -v brew >/dev/null || { echo "Homebrew required"; exit 1; }
command -v fnm  >/dev/null || brew install fnm
command -v eza  >/dev/null || brew install eza

# 3. external plugins (HTTPS so no SSH key is needed; bash-3.2-safe, no arrays)
mkdir -p "$CUSTOM/plugins" "$CUSTOM/themes"
while IFS='|' read -r name url; do
  [ -n "$name" ] || continue
  dir="$CUSTOM/plugins/$name"
  if [ -d "$dir/.git" ]; then
    echo "Updating plugin $name..."
    git -C "$dir" pull --ff-only || true
  else
    echo "Cloning plugin $name..."
    git clone --depth=1 "$url" "$dir"
  fi
done <<'PLUGINS'
zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git
zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git
zsh-npm-scripts-autocomplete|https://github.com/grigorii-zander/zsh-npm-scripts-autocomplete.git
PLUGINS

# 4. theme symlink (into custom/themes so omz updates don't wipe it)
theme_link="$CUSTOM/themes/alex.zsh-theme"
if [ -e "$theme_link" ] && [ ! -L "$theme_link" ]; then
  mv "$theme_link" "$theme_link.bak.$TS"
fi
ln -sfn "$ZDIR/theme/alex.zsh-theme" "$theme_link"
echo "Linked theme: $theme_link -> $ZDIR/theme/alex.zsh-theme"

# 5. import blocks in the local rc files
add_source() {  # $1 = rc file, $2 = shared file
  local rc="$1" shared="$2"
  [ -f "$rc" ] && cp "$rc" "$rc.bak.$TS"
  if ! grep -q "dotfiles shared (managed" "$rc" 2>/dev/null; then
    {
      echo ""
      echo "# >>> dotfiles shared (managed by macos/zsh/install.sh) >>>"
      echo "[ -f \"$shared\" ] && source \"$shared\""
      echo "# <<< dotfiles shared <<<"
    } >> "$rc"
    echo "Added source block to $rc"
  else
    echo "$rc already wired up"
  fi
}
add_source "$HOME/.zshrc"    "$ZDIR/shared.zshrc"
add_source "$HOME/.zprofile" "$ZDIR/shared.zprofile"

echo
echo "Done. Start a fresh shell with:  exec zsh"
