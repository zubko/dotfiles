#!/bin/bash

cp -r ~/.config/fish .config/
cp -r ~/.config/skhd .config/
cp -r ~/.config/yabai .config/

git add .
git commit -m "Update configs"
git push
