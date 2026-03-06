#!/bin/bash

STATE_FILE="$HOME/.cache/quickshell/theme_mode"

mode="dark"
if [[ -f "$STATE_FILE" ]]; then
  mode="$(<"$STATE_FILE")"
fi

ROFI_DARK="$HOME/.config/rofi/wide.rasi"
ROFI_LIGHT="$HOME/.config/rofi/wide_light.rasi"

if [[ "$mode" == "light" ]]; then
  rofi -show drun -theme "$ROFI_LIGHT"
else
  rofi -show drun -theme "$ROFI_DARK"
fi
