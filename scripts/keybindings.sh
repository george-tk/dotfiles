#!/bin/bash
#  _              _     _           _ _
# | | _____ _   _| |__ (_)_ __   __| (_)_ __   __ _ ___
# | |/ / _ \ | | | '_ \| | '_ \ / _` | | '_ \ / _` / __|
# |   <  __/ |_| | |_) | | | | | (_| | | | | | (_| \__ \
# |_|\_\___|\__, |_.__/|_|_| |_|\__,_|_|_| |_|\__, |___/ 
#           |___/                             |___/ 
# by Stephan Raabe (2024)
# -----------------------------------------------------
# Modified to allow executing binds and custom descriptions.
# For custom descriptions, use '##' in your binds.conf file.
# Example: bind = $mainMod,T, exec, kitty ## Open a terminal

config_file=~/.config/hypr/conf/binds.conf

# Arrays to store commands and what to show in rofi
declare -a commands
declare -a menu_items

# Read binds.conf line by line
while read -r line; do
    # We only care about lines that define a bind
    if ! [[ "$line" =~ ^\s*bind.*= ]]; then
        continue
    fi

    # Separate the description from the bind definition
    description=""
    bind_part="$line"
    if [[ "$line" == *"##"* ]]; then
        description="${line#*## }"
        bind_part="${line%% ##*}"
    elif [[ "$line" == *"#"* ]]; then
        # Fallback to single '#' for existing comments
        description="${line#*#}"
        bind_part="${line%%#*}"
    fi
    description=$(echo "$description" | xargs) # trim whitespace
    # Clean up the bind part to get keys and action
    # action_part=$(echo "$bind_part" | sed -E 's/^\s*bind[a-zA-Z]*\s*=\s*//' | xargs)
    # This removes the 'bind =' part AND swaps SUPER variants for a symbol
    action_part=$(echo "$bind_part" | sed -E 's/^\[?\s*bind[a-zA-Z]*\s*=\s*//' | xargs)
    # The action is everything from the 3rd comma-separated value onwards
    keys_part=$(echo "$action_part" | cut -d, -f1-2)
    command_part=$(echo "$action_part" | cut -d, -f3-)

    # Format keys for display
    keys_display=$(echo "$keys_part" | sed 's/$mainMod/󰍲/g' | sed 's/,\s*/ + /g' |sed 's/^\s*\+\s*//' | sed 's/SHIFT/+ SHIFT/g'|  sed 's/ALT/+ ALT/g'| sed 's/SUPER + SUPER_L/󰍲/g'|  sed 's/CONTROL/+ CTRL/g'|xargs)

    # If no description was found, use the command part as description
    if [ -z "$description" ]; then
        description=$(echo "$command_part" | xargs)
    fi

    # Add to our arrays
    menu_items+=("${keys_display}"$'\r'"${description}")

    dispatcher=$(echo "$command_part" | awk -F, '{print $1}' | xargs)
    params=$(echo "$command_part" | cut -d, -f2- | xargs)

    executable_command=""
    if [ "$dispatcher" == "exec" ]; then
        executable_command="$params"
    else
        executable_command="hyprctl dispatch $dispatcher $params"
    fi
    commands+=("$executable_command")

done < "$config_file"

# Prepare input for rofi
rofi_input=""
for item in "${menu_items[@]}"; do
    rofi_input+="$item\n"
done

# Launch rofi and get the selected index
chosen_index=$(echo -e "${rofi_input}" | rofi -dmenu -i -p "  " -format 'i' -markup -eh 2)

# If an index was returned, execute the command
if [[ -n "$chosen_index" ]] && [[ "$chosen_index" -lt "${#commands[@]}" ]]; then
    command_to_run="${commands[$chosen_index]}"
    if [ -n "$command_to_run" ]; then
        eval "$command_to_run" &>/dev/null &
    fi
fi
