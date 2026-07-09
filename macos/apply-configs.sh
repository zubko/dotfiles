#!/bin/bash
# Apply the tracked macOS .config files from this repo onto this machine.
# Counterpart to collect-configs.sh. Safe to re-run.
set -euo pipefail

CONFIGS="$HOME/dotfiles/macos/.config"
[ -d "$CONFIGS" ] || { echo "Run after cloning dotfiles to ~/dotfiles"; exit 1; }

# skhd and yabai: whole dirs
mkdir -p ~/.config/skhd ~/.config/yabai
cp -v "$CONFIGS/skhd/skhdrc"   ~/.config/skhd/skhdrc
cp -v "$CONFIGS/yabai/yabairc" ~/.config/yabai/yabairc

# revdiff: only the keybindings file — never touch history/, config, or themes/
mkdir -p ~/.config/revdiff
cp -v "$CONFIGS/revdiff/keybindings" ~/.config/revdiff/keybindings

echo "Done."
