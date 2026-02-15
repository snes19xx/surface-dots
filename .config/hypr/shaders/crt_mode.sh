#!/usr/bin/env bash

# CONFIG
home="$HOME"
shader_path="$home/.config/hypr/shaders/crt_mode.glsl"
wallpaper_crt="$home/Pictures/retro/van.png"
current_theme_file="$home/.cache/quickshell/theme_mode"
wallpaper_light="$home/Pictures/desktop/l2.png"
wallpaper_dark="$home/Pictures/desktop/1.png"

# HELPERS
current_shader=$(hyprshade current)

# string.find equivalent in bash
if [[ "$current_shader" == *"crt"* ]]; then
    # [[ DEACTIVATE: CRT MODE OFF ]] 
    
    # Turn off shader
    hyprshade off
    
    # Restore Hyprland defaults
    hyprctl reload

    # Restore shell
    pkill waybar
    qs -c snes-hub &

    # Restore Wallpaper
    saved_theme="dark"
    if [[ -f "$current_theme_file" ]]; then
        saved_theme=$(cat "$current_theme_file" | tr -d '[:space:]')
    fi

    if [[ "$saved_theme" == "light" ]]; then
        swww img "$wallpaper_light" --transition-type none
    else
        swww img "$wallpaper_dark" --transition-type none
    fi
    
    # Send a notification
    notify-send 'CRT Mode' 'Deactivated'



else
    # [[ ACTIVATE: CRT MODE ON ]]
    
    # Enable CRT Shader
    hyprshade on "$shader_path"
    
    #CRT Wallpaper
    swww img "$wallpaper_crt" \
    --transition-type grow \
    --transition-pos 0.5,0.5 \
    --transition-duration 1.5 \
    --transition-fps 60 

    # Disable quickshell
    pkill qs

    # Enable waybar 
    waybar &
    
    # Apply Overrides
    # Constructing the batch string directly
    overrides="keyword debug:damage_tracking 0;\
    keyword decoration:rounding 0;\
    keyword general:gaps_in 0;\
    keyword general:gaps_out 0;\
    keyword general:border_size 3;\
    keyword decoration:rounding 0;\
    keyword general:col.active_border rgba(626c73ff);\
    keyword general:col.inactive_border rgba(626c73ff);\
    keyword decoration:blur:enabled 0;\
    keyword decoration:shadow:enabled 0;\
    keyword animations:enabled 0;\
    keyword decoration:dim_around 0"
    
    hyprctl --batch "$overrides"
    
    notify-send 'CRT Mode' 'Activated'
fi