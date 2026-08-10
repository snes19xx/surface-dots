 #!/usr/bin/env bash
set -euo pipefail
# If playing, show media
if command -v playerctl >/dev/null 2>&1; then
status="$(playerctl status 2>/dev/null || true)"
if [ "$status" = "Playing" ]; then
artist="$(playerctl metadata artist 2>/dev/null || true)"
title="$(playerctl metadata title 2>/dev/null || true)"
text="${artist:+$artist - }$title"
text="${text:0:60}"
jq -nc --arg t " $text" '{text:$t, class:"media", tooltip:$t}'
exit 0
fi
fi

# Otherwise show active window title
if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
title="$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // ""')"
if [ -n "$title" ]; then
short="${title:0:60}"
jq -nc --arg t "$short" --arg tip "$title" '{text:$t, class:"window", tooltip:$tip}'
exit 0
fi
fi
# Nothing to show
jq -nc '{text:"", class:"empty"}' 