#!/bin/bash
#  _              _     _           _ _
# | | _____ _   _| |__ (_)_ __   __| (_)_ __   __ _ ___
# | |/ / _ \ | | | '_ \| | '_ \ / _` | | '_ \ / _` / __|
# |   <  __/ |_| | |_) | | | | | (_| | | | | | (_| \__ \
# |_|\_\___|\__, |_.__/|_|_| |_|\__,_|_|_| |_|\__, |___/ 
#           |___/                             |___/ 
# Optimized version for performance using single-pass parsing.
# -----------------------------------------------------

config_file=~/.config/hypr/conf/binds.conf

# Use awk to parse the file once and output display items and commands on alternating lines.
# This eliminates the overhead of multiple process forks per line.
mapfile -t data < <(awk '
/^[ \t]*bind[a-zA-Z]*[ \t]*=/ {
    line = $0
    # Extract description
    desc = ""; bind_part = line
    if (match(line, /##/)) {
        desc = substr(line, RSTART + 2)
        bind_part = substr(line, 1, RSTART - 1)
    } else if (match(line, /#/)) {
        desc = substr(line, RSTART + 1)
        bind_part = substr(line, 1, RSTART - 1)
    }
    gsub(/^[ \t]+|[ \t]+$/, "", desc)
    
    # Extract bind definition
    sub(/^[ \t]*bind[a-zA-Z]*[ \t]*=[ \t]*/, "", bind_part)
    
    # Split fields: Mod, Key, Dispatcher, Params
    split(bind_part, f, ",")
    keys_part = f[1] "," f[2]
    
    # Format keys for display
    keys_display = keys_part
    gsub(/\$mainMod/, "󰍲", keys_display)
    gsub(/,\s*/, " + ", keys_display)
    gsub(/^[ \t]*\+[ \t]*/, "", keys_display)
    gsub(/SHIFT/, "+ SHIFT", keys_display)
    gsub(/ALT/, "+ ALT", keys_display)
    gsub(/SUPER \+ SUPER_L/, "󰍲", keys_display)
    gsub(/CONTROL/, "+ CTRL", keys_display)
    gsub(/^[ \t]+|[ \t]+$/, "", keys_display)
    gsub(/[ \t]+/, " ", keys_display)

    # Extract dispatcher and parameters
    dispatcher = f[3]; gsub(/^[ \t]+|[ \t]+$/, "", dispatcher)
    
    # Find start of parameters (everything after 2nd comma)
    c = 0; p_start = 0
    for (i=1; i<=length(bind_part); i++) {
        if (substr(bind_part, i, 1) == ",") {
            if (++c == 2) { p_start = i + 1; break }
        }
    }
    params = substr(bind_part, p_start); gsub(/^[ \t]+|[ \t]+$/, "", params)

    if (dispatcher == "exec") {
        executable_command = params
    } else {
        executable_command = "hyprctl dispatch " dispatcher " " params
    }

    if (desc == "") desc = executable_command
    
    # Output alternating lines for mapfile: display text then the command
    print keys_display "\r" desc
    print executable_command
}' "$config_file")

# Split the data into separate arrays for rofi and execution
menu_items=()
commands=()
for ((i=0; i<${#data[@]}; i+=2)); do
    menu_items+=("${data[i]}")
    commands+=("${data[i+1]}")
done

# Prepare rofi input (efficiently joining array elements)
rofi_input=$(printf "%s\n" "${menu_items[@]}")

# Launch rofi and get the selected index
chosen_index=$(echo -e "${rofi_input}" | rofi -dmenu -i -p "  " -format 'i' -markup -eh 2)

# If an index was returned, execute the command
if [[ -n "$chosen_index" ]] && [[ "$chosen_index" -lt "${#commands[@]}" ]]; then
    command_to_run="${commands[$chosen_index]}"
    if [ -n "$command_to_run" ]; then
        eval "$command_to_run" &>/dev/null &
    fi
fi
