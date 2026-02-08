# System Restore & Setup Guide

This repository contains the configuration files (dotfiles) and setup scripts to restore my Arch Linux (Hyprland) environment.

## 🚀 Quick Start

1.  **Clone the repository:**
    ```bash
    git clone <your-repo-url> ~/.config
    cd ~/.config
    ```

2.  **Run the Setup Script:**
    This script installs necessary packages (AUR via `yay`), sets up systemd services, and configures global settings.
    ```bash
    ./scripts/setup.sh
    ```

---

## 🔧 Vital Configuration Details

While the setup script handles most heavy lifting, the following aspects often require manual verification or understanding of how they were achieved.

### 1. Bluetooth & Peripherals
*   **Manager:** `blueman` is used to manage connections.
*   **CLI Alternative:** If the GUI isn't available, use `bluetoothctl`:
    ```bash
    bluetoothctl
    # Inside the prompt:
    power on
    agent on
    default-agent
    scan on
    # Wait for device...
    pair <MAC_ADDRESS>
    connect <MAC_ADDRESS>
    trust <MAC_ADDRESS>
    ```
*   **Connection:**
    *   Ensure the bluetooth service is running: `sudo systemctl enable --now bluetooth`.
    *   Open the manager with **`Super + Shift + B`** (Keybinding defined in `hypr/conf/binds.conf`).
    *   *Note:* If your keyboard/mouse don't auto-connect, use the Search/Pair function in Blueman. The initial successful pairing in the history was likely done via the GUI (`blueman-manager`) after enabling the service.

### 2. Theming (GTK & Thunar)
*   **Theme:** Catppuccin Mocha Blue.
*   **Installation:** The theme was originally installed using the Catppuccin Python installer:
    ```bash
    # (Reference command)
    python3 install.py mocha rosewater
    ```
*   **Consistency Fix:** If Thunar or other GTK apps look generic (adwaita/light theme) instead of Dark/Catppuccin:
    *   Ensure `xdg-desktop-portal-gtk` is installed (The setup script installs `xdg-desktop-portal-hyprland`, but the GTK portal is often needed for legacy app theming).
    *   Run: `sudo pacman -S xdg-desktop-portal-gtk`
    *   Configuration is often handled in `~/.config/gtk-3.0/settings.ini` and via `dconf` (which `setup.sh` doesn't deeply automate, so check `~/.config/gtk-3.0/` is tracked).

### 3. SDDM (Login Screen)
*   **Theme Location:** `/usr/share/sddm/themes/catppuccin-mocha-blue/`
*   **Configuration:** The setup script copies themes from `~/.config/sddm/themes/` to the system directory.
*   **Critical Customization:**
    *   The background image was manually copied: `cp wallpapers/abstract-swirls.jpg sddm/themes/themes/catppuccin-mocha-blue/backgrounds/`.
    *   The config `theme.conf` was edited to point to this wallpaper.
    *   *Ensure:* Your git repo contains the *modified* `sddm/themes` folder so the setup script applies your custom wallpaper automatically.

### 4. Wallpaper Rotation
*   **Mechanism:** A `cron` job runs every 15 minutes.
*   **Script:** `~/.config/scripts/rotate-wallpaper.sh`
*   **Setup:** The `setup.sh` script automatically writes the crontab entry and enables `cronie.service`.
*   **Manual Setup (CLI):**
    If the script fails, you can set it up manually:
    1.  Make the script executable: `chmod +x ~/.config/scripts/rotate-wallpaper.sh`
    2.  Edit crontab: `crontab -e`
    3.  Add the line:
        ```cron
        */15 * * * * /home/georgek/.config/scripts/rotate-wallpaper.sh
        ```
*   **Manual Trigger:** You can test it by running `./scripts/rotate-wallpaper.sh`.

### 5. Base Arch Setup (Prerequisites)
Before running the restore:
*   Install a base Arch Linux system.
*   Create your user (`george`) and add to `wheel`.
*   Install `git`: `pacman -S git`.

### 6. Troubleshooting
*   **Gemini CLI:** If the CLI isn't working, reinstall globally: `sudo npm install -g @google/gemini-cli@latest`.
*   **Monitors/Hyprland:** If monitors behave oddly, check `~/.config/hypr/conf/general.conf` or `hyprland.conf` (history shows edits to `binds.conf` and `hyprland.conf`).
