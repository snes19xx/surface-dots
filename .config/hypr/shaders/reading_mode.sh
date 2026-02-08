#!/usr/bin/env bash

# PATHS
home="$HOME"
shader_path="$home/.config/hypr/shaders/reading_mode.glsl"
theme_script="$home/.config/quickshell/snes-hub/bar/theme-mode.sh"
current_theme_file="$home/.cache/quickshell/theme_mode"
restore_file="$home/.cache/quickshell/reading_mode_restore"
wallpaper_reading="$home/Pictures/desktop/WP/6.jpg"


# SWITCHER
# Check if shader is active
current_shader=$(hyprshade current)

if [[ "$current_shader" == *"reading_mode"* ]]; then

    # [[ DEACTIVATE: TURN OFF READING MODE ]] --

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

    # Cleanup
    rm -f "$restore_file"

    # Restart Shell
    qs -c snes-hub &

    # Send Notification
    notify-send 'Reading Mode' 'off'


else
    # [[ ACTIVATE: TURN ON READING MODE ]] --

    # Save current theme state
    if [[ -f "$current_theme_file" ]]; then
        current_theme=$(cat "$current_theme_file" | tr -d '[:space:]')
    fi
    
    if [[ -z "$current_theme" ]]; then 
        current_theme="dark" 
    fi
    
    echo "$current_theme" > "$restore_file"

    # Enable Shader & Switch to Light Theme
    hyprshade on "$shader_path"
    pkill qs
    $theme_script light

    # Set Wallpaper & Brightness (Async)
    swww img "$wallpaper_reading" --transition-type none &
    brightnessctl set 37% &

    # Apply E-ink Overrides
    # Constructing the batch string directly
    overrides="keyword animations:enabled 0;\
    keyword decoration:shadow:enabled 0;\
    keyword decoration:blur:enabled 0;\
    keyword decoration:rounding 0;\
    keyword general:gaps_in 0;\
    keyword general:gaps_out 0;\
    keyword general:border_size 2;\
    keyword general:col.active_border rgba(000000ff);\
    keyword general:col.inactive_border rgba(000000ff);\
    keyword decoration:dim_inactive 0"
    
    hyprctl --batch "$overrides"

    # Send Notification
    notify-send 'Reading Mode' 'Activated'
fi