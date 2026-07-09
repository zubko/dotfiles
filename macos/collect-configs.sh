#!/bin/bash

cp -r ~/.config/skhd .config/
cp -r ~/.config/yabai .config/

# revdiff: only the keybindings file — skip history/ (private review data) and themes/
mkdir -p .config/revdiff
cp ~/.config/revdiff/keybindings .config/revdiff/

git add .
git commit -m "Update configs"
git push
