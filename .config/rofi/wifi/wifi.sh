#!/bin/bash

# PATHS
DIR="$HOME/.config/rofi/wifi"
THEME="$DIR/wifi.rasi"
PASS_THEME="$DIR/password.rasi"

notify() {
    notify-send "WiFi Manager" "$1"
}

status_out=$(nmcli -t -f ACTIVE,SSID dev wifi | grep "^yes" | cut -d: -f2)
if [ -n "$status_out" ]; then
    toggle_opt="Turn Wifi Off"
    status_text="Connected: $status_out"
else
    toggle_opt="Turn Wifi On"
    status_text="Disconnected"
fi

options="$toggle_opt\nScan Networks\nType Manual SSID"

chosen=$(echo -e "$options" | rofi -dmenu -i -p " " -mesg "$status_text" -theme "$THEME")

case "$chosen" in
    "Turn Wifi Off")
        nmcli radio wifi off && notify "Wifi Disabled"
        ;;
    "Turn Wifi On")
        nmcli radio wifi on && notify "Wifi Enabled"
        ;;
    "Scan Networks")
        notify "Scanning for networks..."
        wifi_list=$(nmcli --fields "SSID,SECURITY,BARS" device wifi list | sed 1d | sed 's/  */ /g')
        chosen_network=$(echo "$wifi_list" | rofi -dmenu -i -p "Networks" -theme "$THEME")
        
        ssid=$(echo "$chosen_network" | awk '{print $1}')
        
        if [ -n "$ssid" ]; then
            saved_conn=$(nmcli -g NAME connection show | grep "^$ssid$")
            
            if [ -n "$saved_conn" ]; then
                nmcli connection up id "$ssid" && notify "Connected to $ssid"
            else
                pass=$(rofi -dmenu -password -p "Password" -theme "$PASS_THEME")
                if [ -n "$pass" ]; then
                    nmcli device wifi connect "$ssid" password "$pass" && notify "Connected to $ssid" || notify "Connection Failed"
                fi
            fi
        fi
        ;;
    "Type Manual SSID")
        ssid=$(rofi -dmenu -p "SSID" -theme "$THEME")
        if [ -n "$ssid" ]; then
            pass=$(rofi -dmenu -password -p "Password" -theme "$PASS_THEME")
            nmcli device wifi connect "$ssid" password "$pass"
        fi
        ;;
esac
