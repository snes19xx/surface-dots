#!/usr/bin/env bash
declare -a SHADERS=(
    "Reading Mode|$HOME/.config/hypr/shaders/reading_mode.sh|$HOME/.config/rofi/icons/light/reading.svg"
    "Night Light|$HOME/.config/hypr/shaders/night_light.sh|$HOME/.config/rofi/icons/light/night.svg"
    "CRT Mode|$HOME/.config/hypr/shaders/crt_mode.sh|$HOME/.config/rofi/icons/light/crt.svg"
    "Main|hyprshade off && hyprshade on main|$HOME/.config/rofi/icons/light/main.svg"
    "Outdoor|hyprshade off && hyprshade on outdoor|$HOME/.config/rofi/icons/light/outdoor.svg"
    "Cinema|hyprshade off && hyprshade on cinema|$HOME/.config/rofi/icons/light/cinema.svg"
    "Soft|hyprshade off && hyprshade on soft|$HOME/.config/rofi/icons/light/soft.svg"
    "Matte|hyprshade off && hyprshade on matte|$HOME/.config/rofi/icons/light/matte.svg"
    "IBM 5151|hyprshade off && hyprshade on IMB5151|$HOME/.config/rofi/icons/light/ibm.svg"
    "Fuji Acros|hyprshade off && hyprshade on fuji_acros|$HOME/.config/rofi/icons/light/fuji.svg"
    "VHS|hyprshade off && hyprshade on vhs|$HOME/.config/rofi/icons/light/vhs.svg"
    "Gameboy|hyprshade off && hyprshade on gameboy|$HOME/.config/rofi/icons/light/gameboy.svg"
    "Clarity|hyprshade off && hyprshade on clarity_inefficient|$HOME/.config/rofi/icons/light/clarity.svg"
    "Focus|hyprshade off && hyprshade on focus|$HOME/.config/rofi/icons/light/focus.svg"
    "Night Vision|hyprshade off && hyprshade on night_vision|$HOME/.config/rofi/icons/light/night_vision.svg"
    "Turn Off All|hyprshade off|$HOME/.config/rofi/icons/light/off.svg"
)

if [ -z "$1" ]; then
    for entry in "${SHADERS[@]}"; do
        name="${entry%%|*}"
        icon="${entry##*|}"
        echo -e "$name\0icon\x1f$icon"
    done
else
    for entry in "${SHADERS[@]}"; do
        name="${entry%%|*}"
        if [ "$name" = "$1" ]; then
            command="${entry#*|}"
            command="${command%|*}"
            eval "$command" > /dev/null 2>&1 &
            exit 0
        fi
    done
fi