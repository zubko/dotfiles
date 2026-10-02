#!/usr/bin/env bash
# Pull, show the machine-only lines of the home dotfiles, then commit and push after one confirm.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$REPO"

START_PAT='^[#"] >>> dotfiles shared [(]managed by [^)]*[)] >>>$'
END_PAT='^[#"] <<< dotfiles shared <<<$'

git pull --no-rebase

echo
echo "Machine-only lines (outside the managed blocks):"
for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.tmux.conf" "$HOME/.vimrc"; do
  [ -f "$f" ] || continue
  echo "--- ~${f#"$HOME"}"
  awk -v start="$START_PAT" -v end="$END_PAT" '
    $0 ~ start { skip = 1; next }
    $0 ~ end { skip = 0; next }
    !skip && NF { print }
  ' "$f"
done

echo
git add -A
if git diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi
git diff --cached --stat
printf 'Commit & push? (Y/n) '
read -r answer
case "$answer" in
  ""|y|Y|yes|YES) ;;
  *) echo "Left the changes staged, nothing committed."; exit 0 ;;
esac
git commit -m "update dotfiles"
git push
