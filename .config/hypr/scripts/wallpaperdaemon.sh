#!/bin/bash

swww query
if [ $? -eq 1 ]; then
  swww-daemon --format xrgb &

  swww img ~/.local/state/theme/current_wallpaper \
    --transition-type "wipe" \
    --transition-duration 3
fi