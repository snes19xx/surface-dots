#!/bin/bash

# Paths
THEME_DIR="$HOME/.config/kitty/themes"
TARGET_FILE="$HOME/.local/state/theme/kitty_theme.conf"

# Theme Files
DARK_THEME="everforest.conf"
LIGHT_THEME="everforest_light.conf"

# Check if the target file exists, if not create it
if [ ! -f "$TARGET_FILE" ]; then
    mkdir -p "$(dirname "$TARGET_FILE")"
    touch "$TARGET_FILE"
fi

# Detect current mode by reading the symlink or file content
if grep -q "#f3f5d9" "$TARGET_FILE"; then
    CURRENT_MODE="light"
else
    CURRENT_MODE="dark"
fi

if [ "$CURRENT_MODE" == "dark" ]; then
    echo "Switching to Light Mode..."
    ln -sf "$THEME_DIR/$LIGHT_THEME" "$TARGET_FILE"
    # Send notification 
    notify-send -h string:x-canonical-private-synchronous:sys-notify -u low "Theme" "Switched to Light Mode"
else
    echo "Switching to Dark Mode..."
    ln -sf "$THEME_DIR/$DARK_THEME" "$TARGET_FILE"
    # Send notification
    notify-send -h string:x-canonical-private-synchronous:sys-notify -u low "Theme" "Switched to Dark Mode"
fi

# Reload Kitty instances
kill -SIGUSR1 $(pidof kitty)