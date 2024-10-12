#!/bin/bash

# ensure proper directory
current_dir=$(basename "$(pwd)")
if [ "$current_dir" != "dotfiles" ]; then
    echo "Error: Current directory is not 'dotfiles'"
    echo "Current directory: $(pwd)"
    exit 1
fi

# update repo
echo "Getting the latest changes from Git repo..."
git pull

# copy configs
echo "Copying dotfiles from this folder..."
rsync -av --update --include=".*" ./linux/ ~/
