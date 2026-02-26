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
echo "${vol}:${is_muted}" > "$HOME/.cache/quickshell/volume"
printf '%s\n%s\n%s' "$status" "$title" "$artist" > "$HOME/.cache/quickshell/media"
else
echo "${vol}:${is_muted}" > "$HOME/.cache/quickshell/volume"
fi