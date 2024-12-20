#!/bin/bash

# TODO: this is an old way, there is no need to copy the files
# they can be sym-linked to this repo at their locations
# check linux/setup.sh

current_dir=$(basename "$(pwd)")

if [ "$current_dir" != "dotfiles" ]; then
    echo "Error: Current directory is not 'dotfiles'"
    echo "Current directory: $(pwd)"
    exit 1
fi

echo "Getting the latest changes from Git repo..."

git pull

echo "Copying dotfiles to this folder..."

cp -r -v ~/.tmux.conf linux/
cp -r -v ~/.gitconfig linux/
cp -r -v ~/.bash_aliases linux/
cp -r -v ~/.vimrc linux/

mkdir -p linux/.config

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
