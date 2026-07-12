#!/usr/bin/env bash
# Reads the quickshell weather cache and prints Pango markup for the lockscreen:
#   <icon>  <desc> <temp>
# Exits with empty output if the cache is missing/unreadable so the label stays blank.
f="/home/snes/.config/quickshell/.cache/weather.json"
[ -r "$f" ] || exit 0

IFS=$'\t' read -r icon desc temp <<< "$(jq -r '.icon + "\t" + .desc + "\t" + .temp' "$f" 2>/dev/null)"
[ -z "$desc" ] && exit 0

printf '<span foreground="#c8c1b2">%s  <span style="italic">%s</span> %s</span>' "$icon" "$desc" "$temp"
