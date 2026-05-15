#!/usr/bin/env bash

# Format: "Display Name|ShaderPath|IconPath"

declare -a SHADERS=(
    "Reading Mode|$HOME/.config/hypr/shaders/reading_mode.glsl|$HOME/.config/rofi/icons/light/reading.svg"
    "Night Light|$HOME/.config/hypr/shaders/night.glsl|$HOME/.config/rofi/icons/light/night.svg"
    "CRT Mode|$HOME/.config/hypr/shaders/crt_mode.glsl|$HOME/.config/rofi/icons/light/crt.svg"
    "Main|$HOME/.config/hypr/shaders/main.glsl|$HOME/.config/rofi/icons/light/main.svg"
    "Outdoor|$HOME/.config/hypr/shaders/outdoor.glsl|$HOME/.config/rofi/icons/light/outdoor.svg"
    "Cinema|$HOME/.config/hypr/shaders/cinema.glsl|$HOME/.config/rofi/icons/light/cinema.svg"
    "Amano|$HOME/.config/hypr/shaders/amano.glsl|$HOME/.config/rofi/icons/light/soft.svg"
    "Art Canvas|$HOME/.config/hypr/shaders/art_canvas.glsl|$HOME/.config/rofi/icons/light/canvas.svg"
    "Dither|$HOME/.config/hypr/shaders/dither.glsl|$HOME/.config/rofi/icons/light/dither.svg"
    "Fuji Acros|$HOME/.config/hypr/shaders/fuji_acros.glsl|$HOME/.config/rofi/icons/light/fuji.svg"
    "VHS|$HOME/.config/hypr/shaders/vhs.glsl|$HOME/.config/rofi/icons/light/vhs.svg"
    "Gameboy|$HOME/.config/hypr/shaders/gameboy.glsl|$HOME/.config/rofi/icons/light/gameboy.svg"
    "Silent Hill|$HOME/.config/hypr/shaders/silent_hill.glsl|$HOME/.config/rofi/icons/light/sh.svg"
    "Smart Invert|$HOME/.config/hypr/shaders/smart_invert.glsl|$HOME/.config/rofi/icons/light/invert.svg"
    "Greens|$HOME/.config/hypr/shaders/greens.glsl|$HOME/.config/rofi/icons/light/green.svg"
    "Turn Off All|OFF|$HOME/.config/rofi/icons/light/off.svg"
)

# Function to find the first available (non-active) workspace ID
get_unused_workspace() {
    local active_workspaces
    active_workspaces=$(hyprctl workspaces -j | jq '.[] | .id')
    local ws=1
    while echo "$active_workspaces" | grep -q "^$ws$"; do
        ((ws++))
    done
    echo "$ws"
}

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
            shader="${entry#*|}"
            shader="${shader%|*}"

            # Identify and move to an unused workspace
            wsId=$(get_unused_workspace)
            hyprctl dispatch "hl.dsp.focus({ workspace = $wsId })" > /dev/null 2>&1

            if [ "$shader" = "OFF" ]; then
                # Disable shader
                hyprctl reload > /dev/null 2>&1 &
            else
                hyprctl eval "hl.config({
                    decoration = {
                        screen_shader = \"$shader\"
                    }
                })" > /dev/null 2>&1 &
            fi

            exit 0
        fi
    done
fi