#!/usr/bin/env bash
# Wire tmux, zsh, git, vim and nvim on this machine to the files in this repo.
# Safe to re-run. Set DOTFILES_SKIP_SYSTEM=1 to skip package installs and chsh.
set -euo pipefail

# Not exported on purpose: the oh-my-zsh installer reads REPO from the environment.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
OMZ="$HOME/.oh-my-zsh"
CUSTOM="$OMZ/custom"
TS="$(date +%Y%m%d_%H%M%S)"
OMZ_INSTALLER_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# shared.zshrc puts ~/.local/bin on the PATH. The script must see the same tools (nvim, fnm).
PATH="$HOME/.local/bin:$PATH"

START_PAT='^[#"] >>> dotfiles shared [(]managed by [^)]*[)] >>>$'
END_PAT='^[#"] <<< dotfiles shared <<<$'

case "$(uname)" in
  Darwin) PLATFORM=macos ;;
  Linux) PLATFORM=linux ;;
  *) echo "error: unsupported OS: $(uname)" >&2; exit 1 ;;
esac

SUMMARY=""
report() {
  local name="$1"
  case "$name" in
    "$HOME"/*) name="~${name#"$HOME"}" ;;
  esac
  SUMMARY="$SUMMARY  $name: $2"$'\n'
}

# --- 1. packages ---

package_for() {
  case "$1" in
    nvim) echo neovim ;;
    rg) echo ripgrep ;;
    *) echo "$1" ;;
  esac
}

install_packages_macos() {
  local cmd pkg
  command -v brew >/dev/null || { echo "error: Homebrew is required: https://brew.sh" >&2; exit 1; }
  for cmd in zsh tmux git vim nvim rg eza fnm; do
    command -v "$cmd" >/dev/null && continue
    pkg="$(package_for "$cmd")"
    echo "Installing $pkg..."
    brew install "$pkg"
  done
  # nvim-treesitter builds its parsers with cc
  command -v cc >/dev/null || echo "cc: run xcode-select --install"
}

# Prints the nvim version, or nothing when nvim is missing.
nvim_version() {
  command -v nvim >/dev/null || return 0
  nvim --version | sed -n '1s/^NVIM v//p'
}

# NvChad needs vim.uv, which came in 0.10.
nvim_is_new_enough() {
  local ver="$1" major minor
  case "$ver" in
    [0-9]*.[0-9]*) ;;
    *) return 1 ;;
  esac
  major="${ver%%.*}"
  minor="${ver#*.}"
  minor="${minor%%[!0-9]*}"
  [ "$major" -gt 0 ] || [ "$minor" -ge 10 ]
}

# apt neovim is too old on Debian stable, so Linux gets the GitHub release.
install_nvim_linux() {
  local arch tarball url tmp opt="$HOME/.local/opt/nvim"
  case "$(uname -m)" in
    x86_64) arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "nvim: no release tarball for $(uname -m), install it by hand"; return 0 ;;
  esac
  tarball="nvim-linux-$arch.tar.gz"
  url="https://github.com/neovim/neovim/releases/latest/download/$tarball"
  tmp="$(mktemp -d "$HOME/.nvim-install.XXXXXX")"
  echo "Downloading $url..."
  if ! curl -fsSL -o "$tmp/$tarball" "$url" || ! tar -xzf "$tmp/$tarball" -C "$tmp"; then
    rm -rf "$tmp"
    echo "nvim: download failed, see https://github.com/neovim/neovim/releases"
    return 0
  fi
  mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
  rm -rf "$opt"
  mv "$tmp/nvim-linux-$arch" "$opt"
  rm -rf "$tmp"
  ln -sfn "$opt/bin/nvim" "$HOME/.local/bin/nvim"
  echo "Installed nvim $(nvim_version) to $opt"
}

install_fnm_linux() {
  echo "Installing fnm..."
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell \
    || echo "fnm: install failed, see https://github.com/Schniz/fnm#installation"
}

install_packages_linux() {
  local cmd pkg updated=0
  # gcc: nvim-treesitter builds its parsers with it. rg: telescope live_grep needs it.
  for cmd in curl unzip gcc zsh tmux git vim rg eza; do
    command -v "$cmd" >/dev/null && continue
    pkg="$(package_for "$cmd")"
    if [ "$updated" = 0 ]; then
      sudo apt-get update
      updated=1
    fi
    echo "Installing $pkg..."
    if ! sudo apt-get install -y "$pkg"; then
      case "$pkg" in
        eza) echo "eza: see https://github.com/eza-community/eza/blob/main/INSTALL.md" ;;
        *) echo "$pkg: install failed, install it by hand" ;;
      esac
    fi
  done
  # gcc only recommends libc6-dev, and a minimal apt skips recommends. Without it cc finds no headers.
  if [ ! -e /usr/include/stdio.h ]; then
    sudo apt-get install -y libc6-dev || echo "libc6-dev: install failed, nvim-treesitter cannot build parsers"
  fi
  nvim_is_new_enough "$(nvim_version)" || install_nvim_linux
  command -v fnm >/dev/null || install_fnm_linux
}

# --- 2. login shell ---

set_login_shell() {
  local user current zsh_path
  user="$(id -un)"
  if [ "$PLATFORM" = macos ]; then
    current="$(dscl . -read "/Users/$user" UserShell 2>/dev/null | sed 's/^UserShell: //' || true)"
  else
    current="$(getent passwd "$user" | cut -d: -f7 || true)"
  fi
  case "$current" in
    */zsh) return 0 ;;
  esac
  zsh_path="$(command -v zsh)"
  echo "Changing the login shell to $zsh_path..."
  if [ "$PLATFORM" = macos ]; then
    chsh -s "$zsh_path" || echo "chsh failed, run it by hand: chsh -s $zsh_path"
  else
    sudo chsh -s "$zsh_path" "$user" || echo "chsh failed, run it by hand: sudo chsh -s $zsh_path $user"
  fi
}

# --- 3. oh-my-zsh ---

install_omz() {
  local tmp
  [ -f "$OMZ/oh-my-zsh.sh" ] && return 0
  # KEEP_ZSHRC only keeps a file that exists. Without one the installer writes its own template.
  touch "$HOME/.zshrc"
  tmp="$(mktemp "$HOME/.omz-install.XXXXXX")"
  echo "Downloading the oh-my-zsh installer..."
  if ! curl -fsSL -o "$tmp" "$OMZ_INSTALLER_URL"; then
    rm -f "$tmp"
    echo "error: could not download the oh-my-zsh installer from $OMZ_INSTALLER_URL" >&2
    exit 1
  fi
  if [ -e "$OMZ" ]; then
    echo "Moving the incomplete $OMZ to $OMZ.backup.$TS"
    mv "$OMZ" "$OMZ.backup.$TS"
  fi
  echo "Installing oh-my-zsh..."
  ZSH="$OMZ" RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$tmp" --unattended --keep-zshrc
  rm -f "$tmp"
  [ -f "$OMZ/oh-my-zsh.sh" ] || { echo "error: oh-my-zsh install failed, $OMZ/oh-my-zsh.sh is missing" >&2; exit 1; }
}

install_omz_plugins() {
  local name url dir
  mkdir -p "$CUSTOM/plugins" "$CUSTOM/themes"
  while IFS='|' read -r name url; do
    [ -n "$name" ] || continue
    dir="$CUSTOM/plugins/$name"
    if [ -d "$dir/.git" ]; then
      git -C "$dir" pull -q --ff-only || echo "plugin $name: update failed, kept the current version"
    else
      echo "Cloning plugin $name..."
      git clone -q --depth=1 "$url" "$dir"
    fi
  done <<'PLUGINS'
zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git
zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git
zsh-npm-scripts-autocomplete|https://github.com/grigorii-zander/zsh-npm-scripts-autocomplete.git
PLUGINS
}

link_theme() {
  local link="$CUSTOM/themes/alex.zsh-theme" target="$REPO/shared/zsh/theme/alex.zsh-theme"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    report "omz theme link" "already in place"
    return 0
  fi
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    mv "$link" "$link.bak.$TS"
  fi
  ln -sfn "$target" "$link"
  report "omz theme link" "changed"
}

# --- 4. managed blocks ---

# write_block FILE COMMENTCHAR LINE
# Appends the managed block to FILE, or rewrites the one that is there.
write_block() {
  local f="$1" c="$2" line="$3" starts=0 ends=0 start_at end_at tmp
  if [ -f "$f" ]; then
    starts="$(grep -cE "$START_PAT" "$f" || true)"
    ends="$(grep -cE "$END_PAT" "$f" || true)"
  fi
  if [ "$starts" = 1 ] && [ "$ends" = 1 ]; then
    start_at="$(grep -nE "$START_PAT" "$f" | cut -d: -f1)"
    end_at="$(grep -nE "$END_PAT" "$f" | cut -d: -f1)"
    [ "$start_at" -lt "$end_at" ] || starts=bad
  fi
  if [ "$starts" != 0 ] && [ "$starts" != 1 ] || [ "$starts" != "$ends" ]; then
    echo "error: $f has a broken managed block ($starts start markers, $ends end markers). Fix it by hand." >&2
    exit 1
  fi

  tmp="$(mktemp "$f.tmp.XXXXXX")"
  if [ "$starts" = 0 ]; then
    {
      if [ -s "$f" ]; then
        awk 1 "$f"
        echo ""
      fi
      echo "$c >>> dotfiles shared (managed by install.sh) >>>"
      echo "$line"
      echo "$c <<< dotfiles shared <<<"
    } > "$tmp"
  else
    awk -v start="$START_PAT" -v end="$END_PAT" -v c="$c" -v line="$line" '
      $0 ~ start { print c " >>> dotfiles shared (managed by install.sh) >>>"; print line; print c " <<< dotfiles shared <<<"; skip = 1; next }
      $0 ~ end { skip = 0; next }
      !skip { print }
    ' "$f" > "$tmp"
  fi

  if [ -f "$f" ] && cmp -s "$tmp" "$f"; then
    rm -f "$tmp"
    report "$f" "already in place"
    return 0
  fi
  if [ -s "$f" ]; then
    cp "$f" "$f.bak.$TS"
  fi
  # cat, not mv: a symlinked home file must stay a symlink
  cat "$tmp" > "$f"
  rm -f "$tmp"
  report "$f" "changed"
}

add_git_include() {
  local target="$REPO/shared/git/gitconfig"
  if git config --global --get-all include.path 2>/dev/null | grep -qxF "$target"; then
    report "$HOME/.gitconfig" "already in place"
    return 0
  fi
  git config --global --add include.path "$target"
  report "$HOME/.gitconfig" "changed"
}

link_nvim() {
  local link="$HOME/.config/nvim" target="$REPO/shared/nvim" ver
  ver="$(nvim_version)"
  if [ -z "$ver" ]; then
    report "$HOME/.config/nvim" "skipped (nvim not installed)"
    return 0
  fi
  if ! nvim_is_new_enough "$ver"; then
    report "$HOME/.config/nvim" "skipped (nvim $ver < 0.10, NvChad needs 0.10+)"
    return 0
  fi
  mkdir -p "$HOME/.config"
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$target" ]; then
      report "$HOME/.config/nvim" "already in place"
      return 0
    fi
  elif [ -e "$link" ]; then
    mv "$link" "$link.backup.$TS"
  fi
  ln -sfn "$target" "$link"
  report "$HOME/.config/nvim" "changed"
}

# --- main ---

if [ "${DOTFILES_SKIP_SYSTEM:-}" != 1 ]; then
  "install_packages_$PLATFORM"
  set_login_shell
fi

install_omz
install_omz_plugins

write_block "$HOME/.zshrc" '#' "[ -f \"$REPO/shared/zsh/shared.zshrc\" ] && source \"$REPO/shared/zsh/shared.zshrc\""
write_block "$HOME/.zprofile" '#' "[ -f \"$REPO/$PLATFORM/zsh/zprofile\" ] && source \"$REPO/$PLATFORM/zsh/zprofile\""
write_block "$HOME/.tmux.conf" '#' "source-file \"$REPO/shared/tmux/tmux.conf\""
write_block "$HOME/.vimrc" '"' "source $REPO/shared/vim/vimrc"
add_git_include
link_nvim
link_theme

echo
echo "Summary:"
printf '%s' "$SUMMARY"
echo
echo "Done. Start a fresh shell with: exec zsh"
