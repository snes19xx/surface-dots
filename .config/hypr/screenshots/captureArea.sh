#!/bin/bash
set -euo pipefail

# 1. Get Selection Geometry (Esc => exit cleanly)
geom=$(slurp || true)
[ -z "$geom" ] && exit 1

# 2. Define Filename
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +'%s_grim.png')"

# 3. Capture the Screenshot
grim -g "$geom" "$file"

# 3.5 Copy immediately (raw capture)
if command -v wl-copy >/dev/null 2>&1; then
  wl-copy --type image/png < "$file"
fi

# 4. Audio Feedback
if command -v play >/dev/null 2>&1; then
  play "$HOME/.config/hypr/assets/sounds/camera-shutter.ogg" >/dev/null 2>&1 &
fi

# 5. Open Swappy, and force the final buffer to overwrite $file on exit
swappy -f "$file" -o "$file"

# 6. Copy again after Swappy closes (now it's the annotated version, if you drew anything)
if command -v wl-copy >/dev/null 2>&1; then
  wl-copy --type image/png < "$file"
fi
