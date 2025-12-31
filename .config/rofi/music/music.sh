#!/bin/bash
# Configuration
theme="$HOME/.config/rofi/music/music.rasi"
cover="/tmp/cover.png"
# 1. METADATA & ART
player_status=$(playerctl status 2>/dev/null)
if [ -z "$player_status" ]; then exit 0; fi
artist=$(playerctl metadata artist 2>/dev/null)
title=$(playerctl metadata title 2>/dev/null)
artUrl=$(playerctl metadata mpris:artUrl 2>/dev/null)
# Fallbacks
[ -z "$artist" ] && artist="Unknown"
[ -z "$title" ] && title="Unknown"

# Truncate title if too long (prevents overflow)
if [ ${#title} -gt 45 ]; then
    title="${title:0:42}..."
fi

# Pango Escape
artist=$(echo "$artist" | sed 's/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g')
title=$(echo "$title" | sed 's/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g')

# IMAGE PROCESSING
# Force 250x250 size
if [[ "$artUrl" == file://* ]]; then
    file_path="${artUrl#file://}"
    convert "$file_path" -resize 250x250^ -gravity center -extent 250x250 "$cover"
elif [[ "$artUrl" == http* ]]; then
    curl -s "$artUrl" -o /tmp/cover_raw
    convert /tmp/cover_raw -resize 250x250^ -gravity center -extent 250x250 "$cover"
else
    # Create a placeholder if no art exists
    convert -size 250x250 xc:#1E2326 "$cover"
fi

sleep 0.1

# 2. PROGRESS BAR - REDUCED TO 15 CHARACTERS
pos=$(playerctl metadata --format '{{position}}' 2>/dev/null)
len=$(playerctl metadata --format '{{mpris:length}}' 2>/dev/null)
bar=""
if [ -n "$pos" ] && [ -n "$len" ] && [ "$len" -gt 0 ]; then
    percent=$(echo "$pos * 100 / $len" | bc)
    filled=$(echo "$percent * 15 / 100" | bc)
    empty=$((15 - filled))
    
    for ((i=0; i<filled; i++)); do bar+="━"; done
    for ((i=0; i<empty; i++)); do bar+="─"; done
else
    bar="───────────────"
fi

# 3. DYNAMIC FONT SIZE BASED ON TITLE LENGTH
title_length=${#title}
if [ "$title_length" -gt 35 ]; then
    title_size="small"
elif [ "$title_length" -gt 25 ]; then
    title_size="medium"
else
    title_size="large"
fi

# 4. CONSTRUCT TEXT WITH DYNAMIC SIZING
read -r -d '' display_text <<EOM
<span size='$title_size'><b>$title</b></span>
<span size='small' color='#9da9a0'>$artist</span>

<span size='large' color='#A7C080'>$bar</span>
EOM

# 5. BUTTONS - Define once and use consistently
prev="⏮"
next="⏭"
if [ "$player_status" = "Playing" ]; then
    toggle="⏸"
else
    toggle="⏵"
fi

# 6. RENDER ROFI - Loop for single-click behavior
while true; do
    options="$prev\n$toggle\n$next"
    chosen=$(echo -e "$options" | rofi -dmenu -theme "$theme" -p "" -mesg "$display_text" -selected-row 1)
    
    # Exit if nothing chosen (ESC pressed)
    if [ -z "$chosen" ]; then
        exit 0
    fi
    
    # 7. MATCH USING THE SAME VARIABLES
    if [ "$chosen" = "$prev" ]; then
        playerctl previous
        exit 0
    elif [ "$chosen" = "$toggle" ]; then
        playerctl play-pause
        exit 0
    elif [ "$chosen" = "$next" ]; then
        playerctl next
        exit 0
    fi
done