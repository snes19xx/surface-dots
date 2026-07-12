#!/bin/bash

awww query
if [ $? -eq 1 ]; then
  awww-daemon --format xrgb &

  awww img ~/.local/state/theme/current_wallpaper \
    --transition-type "wipe" \
    --transition-duration 3
fi