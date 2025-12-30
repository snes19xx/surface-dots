#!/usr/bin/env sh

current_perc=$(brightnessctl info | grep -oP "(?<=\()\d+(?=%)" | head -1)

case $1 in
  i) 
    brightnessctl set +5% > /dev/null
    ;;
  d) 
    if [ "$current_perc" -le 5 ]; then
        brightnessctl set 1% > /dev/null
    else
        brightnessctl set 5%- > /dev/null
    fi
    ;;
  *) 
    echo "Usage: $0 {i|d}" 
    exit 1 
    ;;
esac


new_perc=$(brightnessctl info | grep -oP "(?<=\()\d+(?=%)" | head -1)

notify-send -c brightness \
            -h string:x-canonical-private-synchronous:brightness \
            -h int:value:"$new_perc" \
            -u low \
            "Brightness: ${new_perc}%"