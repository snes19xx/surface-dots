#!/usr/bin/env bash

# Map shader names to their specific scripts or generic hyprshade commands.
# Format: "Display Name|Command|IconPath"

declare -a SHADERS=(
    "Reading Mode|$HOME/.config/hypr/shaders/reading_mode.sh|$HOME/.config/rofi/icons/reading.svg"
    "Night Light|$HOME/.config/hypr/shaders/night_light.sh|$HOME/.config/rofi/icons/night.svg"
    "CRT Mode|$HOME/.config/hypr/shaders/crt_mode.sh|$HOME/.config/rofi/icons/crt.svg"
    "Main|hyprshade off && hyprshade on main|$HOME/.config/rofi/icons/main.svg"
    "Outdoor|hyprshade off && hyprshade on outdoor|$HOME/.config/rofi/icons/outdoor.svg"
    "Cinema|hyprshade off && hyprshade on cinema|$HOME/.config/rofi/icons/cinema.svg"
    "Soft|hyprshade off && hyprshade on soft|$HOME/.config/rofi/icons/soft.svg"
    "Matte|hyprshade off && hyprshade on matte|$HOME/.config/rofi/icons/matte.svg"
    "IBM 5151|hyprshade off && hyprshade on IBM5151|$HOME/.config/rofi/icons/ibm.svg"
    "Fuji Acros|hyprshade off && hyprshade on fuji_acros|$HOME/.config/rofi/icons/fuji.svg"
    "VHS|hyprshade off && hyprshade on vhs|$HOME/.config/rofi/icons/vhs.svg"
    "Gameboy|hyprshade off && hyprshade on gameboy|$HOME/.config/rofi/icons/gameboy.svg"
    "Clarity|hyprshade off && hyprshade on clarity_inefficient|$HOME/.config/rofi/icons/clarity.svg"
    "Focus|hyprshade off && hyprshade on focus|$HOME/.config/rofi/icons/focus.svg"
    "Night Vision|hyprshade off && hyprshade on night_vision|$HOME/.config/rofi/icons/night_vision.svg"
    "Turn Off All|hyprshade off|$HOME/.config/rofi/icons/off.svg"
)

# If no argument is passed, output the menu list
if [ -z "$1" ]; then
    for entry in "${SHADERS[@]}"; do
        name="${entry%%|*}"
        icon="${entry##*|}"
        # Rofi protocol for passing icons: \0icon\x1f<path>
        echo -e "$name\0icon\x1f$icon"
    done
else
    # An argument was passed, execute the matching command quietly
    for entry in "${SHADERS[@]}"; do
        name="${entry%%|*}"
        if [ "$name" = "$1" ]; then
            command="${entry#*|}"
            command="${command%|*}"
            
            # Execute, silence all output, and detach process
            eval "$command" > /dev/null 2>&1 &
            exit 0
        fi
    done
fi