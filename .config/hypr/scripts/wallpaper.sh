#!/bin/bash

set -u

THEME_SCRIPT="$HOME/.config/quickshell/utils/theme-mode.sh"
STATE_FILE="$HOME/.cache/quickshell/theme_mode"
# Optional per-monitor override. Set both to give one display a wallpaper of its
# own; leave either empty and every display gets the theme wallpaper.
# MONITOR_MATCH is matched against the description in `hyprctl monitors -j`.
MONITOR_MATCH="${MONITOR_MATCH:-}"
MONITOR_WALLPAPER="${MONITOR_WALLPAPER:-}"

command -v awww >/dev/null 2>&1 || exit 0

TRANSITION=()
if [[ "${1:-}" == "--transition" ]]; then
  TRANSITION=(--transition-type wipe --transition-pos center --transition-step 90 --transition-duration 1.2)
fi

# WALLPAPER_DARK / WALLPAPER_LIGHT
eval "$(grep -E '^WALLPAPER_(DARK|LIGHT)=' "$THEME_SCRIPT")"

mode="$(cat "$STATE_FILE" 2>/dev/null || echo dark)"
if [[ "$mode" == "light" ]]; then
  theme_wallpaper="$WALLPAPER_LIGHT"
else
  theme_wallpaper="$WALLPAPER_DARK"
fi

if ! monitors="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | "\(.name) \(.description)"')" \
   || [[ -z "$monitors" ]]; then
  [[ -f "$theme_wallpaper" ]] && awww img "$theme_wallpaper" ${TRANSITION[@]+"${TRANSITION[@]}"}
  exit 0
fi

# Only enabled outputs show up here
while read -r name desc; do
  if [[ -n "$MONITOR_MATCH" && -n "$MONITOR_WALLPAPER" && "$desc" == *"$MONITOR_MATCH"* ]]; then
    wallpaper="$MONITOR_WALLPAPER"
  else
    wallpaper="$theme_wallpaper"
  fi
  [[ -f "$wallpaper" ]] && awww img -o "$name" "$wallpaper" ${TRANSITION[@]+"${TRANSITION[@]}"}
done <<< "$monitors"
