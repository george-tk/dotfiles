#!/bin/bash

# If Rofi is already running, kill it
if pgrep -x "rofi" > /dev/null; then
    pkill rofi
else
    # Just open Rofi. Our background script will handle Waybar automatically.
    rofi -show combi
fi
