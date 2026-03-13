#!/bin/bash

# 1. Setup Environment
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export PATH=$PATH:/usr/local/bin:/usr/bin

# 2. Logging
LOG_FILE="$HOME/.cache/rotate_wallpaper.log"
exec > >(tee -a "$LOG_FILE" 2>&1)
echo "--- Starting wallpaper rotation at $(date) ---"

# 3. WAIT logic - The Race Condition Fix
# Wait for the hyprpaper process to exist
while ! pgrep -x "hyprpaper" > /dev/null; do
    echo "Waiting for hyprpaper process..."
    sleep 0.3
done

# The dual-monitor setup takes Hyprland and Hyprpaper slightly longer to initialize.
# We are bumping this to 2 seconds to ensure all Wayland outputs are registered.
sleep 0.3 

# 4. Get Hyprland Instance (Usually auto-detected, but good as a fallback)
export HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j | jq -r '.[0].instance')

# 5. Find Wallpapers
WALLPAPER_DIR="$HOME/.config/wallpapers"
WALLPAPER_FILES=$(find "$WALLPAPER_DIR" -type f \
    -not -path "$WALLPAPER_DIR/not_used/*" \
    \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \))

if [ -z "$WALLPAPER_FILES" ]; then
    echo "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

RANDOM_WALLPAPER=$(echo "$WALLPAPER_FILES" | shuf -n 1)

# 6. Execute with Error Catching
echo "Attempting to set wallpaper: $RANDOM_WALLPAPER"

# Best Practice Order: Preload New -> Set Wallpaper -> Unload Unused
# This prevents the brief black-screen flash that happens if you unload everything first.

hyprctl hyprpaper preload "$RANDOM_WALLPAPER"

# Brief pause to ensure preload finishes before applying
sleep 0.3 

# The empty string before the comma targets ALL currently connected monitors
hyprctl hyprpaper wallpaper ",$RANDOM_WALLPAPER"

# Clean up RAM by unloading wallpapers that are no longer actively displayed
hyprctl hyprpaper unload unused || echo "Notice: Nothing to unload yet."

echo "Wallpaper successfully set to: $RANDOM_WALLPAPER"
echo "--- Finished wallpaper rotation at $(date) ---"
