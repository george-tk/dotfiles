#!/usr/bin/env bash

# Check Wi-Fi status
wifi_state=$(nmcli -fields WIFI g | sed -n '2p' | xargs)
[[ "$wifi_state" == "enabled" ]] && toggle="󰖪  Disable Wi-Fi" || toggle="󰖩  Enable Wi-Fi"

# Get current connection
current_rssi=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
[[ -n "$current_rssi" ]] && status="Connected to: $current_rssi" || status="Disconnected"

# Get List of Networks (excluding current and duplicates)
# We use icons for signal strength
mapfile -t lines < <(nmcli --terse --fields "SECURITY,SSID,BARS" device wifi list | sed 's/^--/󰤭 /' | awk -F: '{print $3 "  " $2 "  " $1 }' | sort -k1 -u)

# Create the Menu
options="$toggle\n󰑐  Manual Entry / Hidden SSID\n󰃢  Disconnect\n---\n$(printf '%s\n' "${lines[@]}")"

# Rofi Prompt
chosen=$(echo -e "$options" | rofi -dmenu -i -p "$status" -config ~/.config/rofi/wifi-config.rasi)

# Logic
case "$chosen" in
    "" | "---") exit ;;
    "󰖩  Enable Wi-Fi") nmcli radio wifi on ;;
    "󰖪  Disable Wi-Fi") nmcli radio wifi off ;;
    "󰃢  Disconnect") nmcli device disconnect wlan0 ;;
    "󰑐  Manual Entry / Hidden SSID")
        manual_ssid=$(rofi -dmenu -p "Enter SSID:" -config ~/.config/rofi/wifi-config.rasi)
        [[ -z "$manual_ssid" ]] && exit
        manual_pass=$(rofi -dmenu -p "Enter Password:" -password -config ~/.config/rofi/wifi-config.rasi)
        nmcli device wifi connect "$manual_ssid" password "$manual_pass"
        ;;
    *)
        # Extract SSID (everything after the icons and spaces)
        ssid=$(echo "$chosen" | awk '{print $NF}')
        # Check if already saved
        if nmcli -t -f name connection show | grep -qx "$ssid"; then
            nmcli connection up "$ssid"
        else
            pass=$(rofi -dmenu -p "Password for $ssid:" -password -config ~/.config/rofi/wifi-config.rasi)
            nmcli device wifi connect "$ssid" password "$pass"
        fi
        ;;
esac

# Send notification (uses Dunst/Libnotify)
if [ $? -eq 0 ] && [ "$chosen" != "$toggle" ]; then
    notify-send "Network Manager" "Action successful: $chosen" -i network-wireless
fi
