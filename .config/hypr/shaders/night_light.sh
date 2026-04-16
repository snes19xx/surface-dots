#!/usr/bin/env bash

# PATHS
home="$HOME"
shader_path="$home/.config/hypr/shaders/night.glsl"
# theme_script="$home/.config/quickshell/top-bar/bar/theme-mode.sh"   #uncomment if using top-bar
theme_script="$home/.config/quickshell/task-bar/utils/theme-mode.sh"  # and comment this
current_theme_file="$home/.cache/quickshell/theme_mode"


# SWITCHER
# Check if shader is active
current_shader=$(hyprshade current)

if [[ "$current_shader" == *"night"* ]]; then

    # [[ DEACTIVATE: TURN OFF NIGHT MODE ]] --

    # Determine which theme to restore
    if [[ -f "$restore_file" ]]; then
        prev_theme=$(cat "$restore_file" | tr -d '[:space:]')
    fi
    
    if [[ -z "$prev_theme" ]]; then
        prev_theme="dark" # Default fallback
    fi

    # Turn off shader (failsafe: hyprctl reload usually turns it off anyways)
    # & restore theme
    hyprshade off &
    $theme_script "$prev_theme" &

    # Restore Hyprland
    hyprctl reload

    echo "off" > "$HOME/.cache/quickshell/night_light"

    # Cleanup
    rm -f "$restore_file"



else
    # [[ ACTIVATE: TURN ON NIGHT MODE ]] --

    # Save current theme state
    if [[ -f "$current_theme_file" ]]; then
        current_theme=$(cat "$current_theme_file" | tr -d '[:space:]')
    fi
    
    if [[ -z "$current_theme" ]]; then 
        current_theme="dark" 
    fi
    
    echo "$current_theme" > "$restore_file"

    # Enable Shader & Switch to dark Theme
    hyprshade on "$shader_path"
    $theme_script dark
    echo "on" > "$HOME/.cache/quickshell/night_light"

    # Set brightness
    brightnessctl set 37% &
fi