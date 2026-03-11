#!/usr/bin/env python3
import os
import socket
import subprocess
import json
import time
import signal

# --- State Tracking ---
# We keep track of the current state internally to minimize hyprctl calls.
waybar_pid = None
is_waybar_visible = None # None means "unknown, check once"
is_rofi_open = False

def get_waybar_pid():
    global waybar_pid
    try:
        pid_str = subprocess.check_output(["pgrep", "-x", "waybar"]).decode().strip()
        waybar_pid = int(pid_str)
        return waybar_pid
    except:
        return None

def toggle_waybar(should_be_visible):
    global waybar_pid, is_waybar_visible
    
    # If we already know it's in the correct state, do nothing.
    if is_waybar_visible == should_be_visible:
        return

    if waybar_pid is None: get_waybar_pid()
    if waybar_pid:
        try:
            os.kill(waybar_pid, signal.SIGUSR1)
            is_waybar_visible = should_be_visible
        except ProcessLookupError:
            get_waybar_pid()
            if waybar_pid:
                try: 
                    os.kill(waybar_pid, signal.SIGUSR1)
                    is_waybar_visible = should_be_visible
                except: pass

def get_initial_state():
    """Check the actual state of the system once at startup."""
    global is_waybar_visible, is_rofi_open
    try:
        # Check Waybar visibility
        layers_output = subprocess.check_output(["hyprctl", "layers", "-j"])
        layers_data = json.loads(layers_output)
        
        is_waybar_visible = False
        is_rofi_open = False
        
        for monitor in layers_data:
            levels = layers_data[monitor].get("levels", {})
            for level_num, layers in levels.items():
                for layer in layers:
                    ns = layer.get("namespace")
                    if ns == "waybar" and int(level_num) == 2:
                        is_waybar_visible = True
                    if ns == "rofi":
                        is_rofi_open = True
    except:
        is_waybar_visible = True # Default to visible on error
        is_rofi_open = False

def get_window_count():
    try:
        output = subprocess.check_output(["hyprctl", "activeworkspace", "-j"])
        data = json.loads(output)
        return data.get("windows", 0)
    except: return 0

def sync():
    global is_rofi_open
    windows = get_window_count()
    
    # Rule: Visible if no windows OR Rofi is open
    should_be_visible = (windows == 0) or is_rofi_open
    toggle_waybar(should_be_visible)

def main():
    global is_rofi_open
    get_waybar_pid()
    get_initial_state()
    
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature: return
        
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    socket_path = os.path.join(runtime_dir, "hypr", signature, ".socket2.sock")
    
    sync()
    
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(socket_path)
                while True:
                    data = s.recv(4096).decode('utf-8', errors='ignore')
                    if not data: break
                    
                    # Split data into individual events (Hyprland sends them separated by \n)
                    events = data.strip().split('\n')
                    
                    needs_sync = False
                    for event in events:
                        # 1. Track Rofi state directly from the socket (No hyprctl needed!)
                        if "openlayer>>rofi" in event:
                            is_rofi_open = True
                            needs_sync = True
                        elif "closelayer>>rofi" in event:
                            is_rofi_open = False
                            needs_sync = True
                        
                        # 2. Selective filtering: only sync for events that change window state
                        elif any(ev in event for ev in ["openwindow", "closewindow", "workspace", "movewindow", "fullscreen"]):
                            needs_sync = True
                    
                    if needs_sync:
                        sync()
        except:
            time.sleep(1)

if __name__ == "__main__":
    main()
