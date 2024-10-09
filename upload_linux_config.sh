#!/bin/bash

current_dir=$(basename "$(pwd)")

if [ "$current_dir" != "dotfiles" ]; then
    echo "Error: Current directory is not 'dotfiles'"
    echo "Current directory: $(pwd)"
    exit 1
fi

echo "Getting the latest changes from Git repo..."

git pull
    
echo "Copying dotfiles to this folder..."

cp -r ~/.tmux.conf ./linux/

echo "The new changes:"

git add .
git diff --staged

echo "Upload the changes? (Y/n)"
read -r confirm
if [ "$confirm" != "y" ] && [ -n "$confirm" ]; then
    exit 1
fi

git commit -m "update Linux config"
git push

exit 0

