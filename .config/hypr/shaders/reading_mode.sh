#!/usr/bin/env bash

# PATHS
home="$HOME"
shader_path="$home/.config/hypr/shaders/reading_mode.glsl"
#theme_script="$home/.config/quickshell/top-bar/bar/theme-mode.sh"     # use this if top-bar
theme_script="$home/.config/quickshell/task-bar/utils/theme-mode.sh"
current_theme_file="$home/.cache/quickshell/theme_mode"
restore_file="$home/.cache/quickshell/reading_mode_restore"
wallpaper_reading="$home/Pictures/desktop/WP/6.jpg"
wallpaper_dark="$home/Pictures/desktop/wpdark.jpg"
wallpaper_light="$home/Pictures/desktop/wplight.jpg"

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

    # Turn off shader (hyprctl reload usually turns it off anyways)
    # & restore theme
    hyprshade off &
    $theme_script "$prev_theme" --quiet &
    echo "off" > "$HOME/.cache/quickshell/reading_mode"

    if [[ "$prev_theme" == "light" ]]; then
        swww img "$wallpaper_light" --transition-type none &
    else
        swww img "$wallpaper_dark" --transition-type none &
    fi
    # Restore Hyprland
    hyprctl reload

    # Cleanup
    rm -f "$restore_file"




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
    $theme_script light --quiet
    echo "on" > "$HOME/.cache/quickshell/reading_mode"

    # Set Wallpaper & Brightness
    sleep 1
    swww img "$wallpaper_reading" --transition-type none&
    brightnessctl set 37% &

    # Apply E-ink Overrides
    # the batch string directly
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

fi