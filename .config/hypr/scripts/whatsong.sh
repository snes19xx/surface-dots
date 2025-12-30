#!/usr/bin/env bash

# PATHS
CACHE_DIR="$HOME/.cache/hyprlock"
COVER="$CACHE_DIR/cover.png"

# Just in case
if [ ! -d "$CACHE_DIR" ]; then mkdir -p "$CACHE_DIR"; fi

# Priority: Spotify > Strawberry > Others
if pgrep -x "spotify" >/dev/null; then
    PLAYER="spotify"
elif pgrep -x "strawberry" >/dev/null; then
    PLAYER="strawberry"
else
    PLAYER=$(playerctl status -f '{{playerName}}' 2>/dev/null | head -n 1)
fi

# CHECK STATUS (If stopped/missing, exit)
if [ -z "$PLAYER" ]; then echo ""; exit 0; fi
STATUS=$(playerctl --player="$PLAYER" status 2>/dev/null)
if [ "$STATUS" != "Playing" ]; then echo ""; exit 0; fi

# GET METADATA
TITLE=$(playerctl --player="$PLAYER" metadata --format "{{ xesam:title }}" 2>/dev/null)
ARTIST=$(playerctl --player="$PLAYER" metadata --format "{{ xesam:artist }}" 2>/dev/null)

# ads filtering
if [[ "$TITLE" == "Advertisement" ]] || \
   [[ "$ARTIST" == "Advertisement" ]] || \
   [[ "$TITLE" == "Spotify" ]] || \
   [[ "$ARTIST" == "Spotify" ]] || \
   [[ "$TITLE" == "Unknown" ]] || \
   [[ "$TITLE" == "Spotify Free" ]]; then
    echo ""
    exit 0
fi

# OUTPUT

case "$1" in
--title)
    echo "${TITLE:0:50}"
    ;;
    
--artist)
    if [[ -z "$ARTIST" ]]; then echo ""; exit 0; fi
    echo "${ARTIST:0:50}"
    ;;
    
--arturl)
    # Get Art URL
    URL=$(playerctl --player="$PLAYER" metadata --format "{{ mpris:artUrl }}" 2>/dev/null)
    if [[ "$URL" == *"googleusercontent"* ]]; then
        URL=$(echo $URL | sed -e 's/http:\/\/googleusercontent.com/spotify.com/0')
    fi

    # Download if valid
    if [[ -n "$URL" ]]; then
        if [[ "$URL" == http* ]]; then
            curl -s -o "$COVER" "$URL"
        elif [[ "$URL" == file* ]]; then
            cp "${URL#file://}" "$COVER"
        fi
        echo "$COVER"
    else
        echo ""
    fi
    ;;
esac