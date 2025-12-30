#!/usr/bin/env sh

case $1 in
  i) pamixer -i 5 ;;
  d) pamixer -d 5 ;;
  m) pamixer -t ;;
  *) echo "Usage: $0 {i|d|m}" ; exit 1 ;;
esac

vol=$(pamixer --get-volume)
is_muted=$(pamixer --get-mute)

if [ "$is_muted" = "true" ]; then
    notify-send -c volume \
        -h string:x-canonical-private-synchronous:volume \
        "Volume: Muted"
else
    notify-send -c volume \
        -h string:x-canonical-private-synchronous:volume \
        -h int:value:"$vol" \
        "Volume: ${vol}%"
fi