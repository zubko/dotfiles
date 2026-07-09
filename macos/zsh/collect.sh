#!/usr/bin/env bash
# Commit & push shared zsh changes. Shared config is sourced live from the repo,
# so day-to-day sync is just this + `git pull` on the other machine.
# Also surfaces local-only lines you might want to promote into shared.zshrc.
set -euo pipefail

cd "$HOME/dotfiles"

echo "Pulling latest..."
git pull --rebase

echo
echo "--- Local lines OUTSIDE the managed block ---"
echo "    (these live only on this machine; move any you want synced into"
echo "     macos/zsh/shared.zshrc by hand)"
for rc in "$HOME/.zshrc" "$HOME/.zprofile"; do
  [ -f "$rc" ] || continue
  echo "### $rc"
  awk '/dotfiles shared \(managed/{m=1} /<<< dotfiles shared <<</{m=0;next} !m' "$rc"
done
echo "---------------------------------------------"
echo

git add -A
if git diff --staged --quiet; then
  echo "No repo changes to commit."
  exit 0
fi
git diff --staged --stat
echo
printf "Commit & push these repo changes? (Y/n) "
read -r ans
case "$ans" in
  n|N) echo "Aborted."; exit 0 ;;
esac
git commit -m "Update shared zsh config"
git push
