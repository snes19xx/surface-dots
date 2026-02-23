#!/bin/bash
# Usage: ./alert.sh "appname" "summary" "body" "icon" "urgency"

URGENCY="$5"

case "$URGENCY" in
    "CRITICAL")
        paplay ~/.config/hypr/sounds/alert.wav
        ;;
    *)
        # Plays for LOW and NORMAL
        paplay ~/.config/hypr/sounds/notification.wav
        ;;
esac