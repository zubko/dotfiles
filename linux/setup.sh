#!/bin/bash

# Define paths
DOTFILES_NVIM="$HOME/dotfiles/linux/.config/nvim"
CONFIG_NVIM="$HOME/.config/nvim"

# Check if dotfiles nvim directory exists
if [ ! -d "$DOTFILES_NVIM" ]; then
    echo "Error: Source directory $DOTFILES_NVIM does not exist"
    echo "Please make sure your dotfiles repository is properly set up"
    exit 1
fi

# Check if nvim config exists and what type it is
if [ -e "$CONFIG_NVIM" ]; then
    if [ -L "$CONFIG_NVIM" ]; then
        # It's a symbolic link - check where it points to
        CURRENT_TARGET=$(readlink "$CONFIG_NVIM")
        if [ "$CURRENT_TARGET" = "$DOTFILES_NVIM" ]; then
            echo "Symbolic link already exists and points to the correct location"
            echo "Current link: $CONFIG_NVIM -> $CURRENT_TARGET"
            exit 0
        else
            echo "Existing symbolic link points to different location:"
            echo "$CONFIG_NVIM -> $CURRENT_TARGET"
            echo "Removing old link and creating new one..."
            rm "$CONFIG_NVIM"
        fi
    else
        # It's a regular directory - backup needed
        echo "Existing nvim config is a regular directory. Creating backup..."
        mv "$CONFIG_NVIM" "$CONFIG_NVIM.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Backup created"
    fi
fi

# Create ~/.config directory if it doesn't exist
mkdir -p "$HOME/.config"

# Create the symbolic link
ln -s "$DOTFILES_NVIM" "$CONFIG_NVIM"

# Verify the link was created successfully
if [ -L "$CONFIG_NVIM" ] && [ -d "$CONFIG_NVIM" ]; then
    echo "Symbolic link created successfully!"
    echo "Your nvim config is now linked to $DOTFILES_NVIM"
else
    echo "Error: Failed to create symbolic link"
    exit 1
fi
