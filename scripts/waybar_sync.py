#!/usr/bin/env python3
import os
import socket
import subprocess
import json
import time
import threading
import signal

# Global cache for Waybar's PID to avoid looking it up every time
waybar_pid = None

def get_waybar_pid():
    global waybar_pid
    try:
        pid_str = subprocess.check_output(["pgrep", "-x", "waybar"]).decode().strip()
        waybar_pid = int(pid_str)
        return waybar_pid
    except:
        return None

def toggle_waybar():
    global waybar_pid
    if waybar_pid is None:
        get_waybar_pid()
    if waybar_pid:
        try:
            os.kill(waybar_pid, signal.SIGUSR1)
        except ProcessLookupError:
            # Waybar might have restarted, refresh PID and try once more
            get_waybar_pid()
            if waybar_pid:
                try:
                    os.kill(waybar_pid, signal.SIGUSR1)
                except:
                    pass

def get_waybar_level():
    try:
        output = subprocess.check_output(["hyprctl", "layers", "-j"])
        data = json.loads(output)
        for monitor in data:
            levels = data[monitor].get("levels", {})
            for level_num, layers in levels.items():
                for layer in layers:
                    if layer.get("namespace") == "waybar":
                        return int(level_num)
        return -1
    except:
        return -1

def get_window_count():
    try:
        output = subprocess.check_output(["hyprctl", "activeworkspace", "-j"])
        data = json.loads(output)
        return data.get("windows", 0)
    except:
        return 0

def is_rofi_running():
    try:
        output = subprocess.check_output(["hyprctl", "layers", "-j"])
        data = json.loads(output)
        for monitor in data:
            levels = data[monitor].get("levels", {})
            for level_num, layers in levels.items():
                for layer in layers:
                    if layer.get("namespace") == "rofi":
                        return True
        return False
    except:
        return False

def sync_waybar():
    windows = get_window_count()
    level = get_waybar_level()
    rofi = is_rofi_running()
    
    # Visible (level 2) if: No windows OR Rofi is open
    should_be_visible = (windows == 0) or rofi
    is_visible = (level == 2)
    
    if should_be_visible != is_visible:
        toggle_waybar()

def poll_loop():
    """Very high-speed polling for instant response"""
    while True:
        try:
            sync_waybar()
        except:
            pass
        time.sleep(0.05)

def main():
    # Find Waybar's PID initially
    get_waybar_pid()

    # Start the high-speed polling thread
    threading.Thread(target=poll_loop, daemon=True).start()

    # Find the socket for events
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        return
        
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    socket_path = os.path.join(runtime_dir, "hypr", signature, ".socket2.sock")
    
    sync_waybar()
    
    # Listen for events (e.g. workspace switch or window open)
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(socket_path)
                while True:
                    data = s.recv(4096).decode('utf-8', errors='ignore')
                    if not data:
                        break
                    # Sync on every event to ensure instant reaction
                    sync_waybar()
        except:
            time.sleep(1)

if __name__ == "__main__":
    main()
