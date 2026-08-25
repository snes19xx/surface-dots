#!/bin/bash

# Starts awww if it isn't up yet, then puts the theme wallpaper back.
if ! awww query >/dev/null 2>&1; then
  awww-daemon --format xrgb &
  sleep 1
  "$HOME/.config/hypr/scripts/wallpaper.sh" --transition
fi
