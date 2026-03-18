#!/usr/bin/env python3
import json
import subprocess
import os

STATE_FILE = "/tmp/hypr_last_master"

def get_hyprctl(cmd):
    result = subprocess.run(['hyprctl', '-j', *cmd.split()], capture_output=True, text=True)
    return json.loads(result.stdout)

def main():
    # Get active workspace and clients
    active_workspace = get_hyprctl('activeworkspace')['id']
    clients = [c for c in get_hyprctl('clients') if c['workspace']['id'] == active_workspace]
    
    if not clients:
        return

    # In master layout, the master is usually the first one in the list
    # but we should ideally check 'at' coordinates or something if we want to be sure.
    # However, Hyprland's 'clients' list for master layout is usually ordered by the stack.
    # Let's sort them by their focus history or just use the first one as master.
    # Actually, the master window in 'master' layout is the one that is NOT in the stack.
    # A better way is to check the 'at' coordinates.
    clients.sort(key=lambda c: (c['at'][0], c['at'][1]))
    master_window = clients[0]

    active_window = get_hyprctl('activewindow')
    if not active_window:
        return

    current_addr = active_window['address']

    if current_addr != master_window['address']:
        # We are swapping a slave to master.
        # Save the current master as the "original master" to toggle back to.
        with open(STATE_FILE, 'w') as f:
            f.write(master_window['address'])
        
        subprocess.run(['hyprctl', 'dispatch', 'layoutmsg', 'swapwithmaster'])
    else:
        # We are on the master window. We want to toggle back.
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE, 'r') as f:
                last_master_addr = f.read().strip()
            
            # Check if last_master_addr still exists in current workspace
            target_exists = any(c['address'] == last_master_addr for c in clients)
            
            if target_exists and last_master_addr != current_addr:
                # Swap with the specific previous master
                subprocess.run(['hyprctl', 'dispatch', 'swapwindow', f'address:{last_master_addr}'])
                # Focus stays on the current window (which is now back at its old position)
                # Actually, user might want focus to stay on the window they are moving.
                # If they were master and swapped back, they are now at the old position.
                return
        
        # Fallback to default behavior if no state or target window gone
        subprocess.run(['hyprctl', 'dispatch', 'layoutmsg', 'swapwithmaster'])

if __name__ == "__main__":
    main()
