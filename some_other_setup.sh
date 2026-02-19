#!/bin/bash
sudo -v  # cache password for ~15min
echo "asking once for sudo"
set -euo pipefail
echo "hopefully no more"
# === CONFIG ===
PROJECT_DIR="$HOME/project"
VENV_DIR="$PROJECT_DIR/.venv"
USER="$(logname || echo "$USER")"

echo "=== Running post‑install setup ==="

# 1. Install Python, pip, git
sudo apt update
sudo apt install -y python3 python3-venv python3-pip git

# 3. Add user to dialout so /dev/ttyUSB0 is accessible
sudo usermod -a -G dialout "$USER"
echo "User '$USER' added to dialout group; log out/in for it to take effect."

# Disable Update Manager and Mint Welcome startup
# === COMPLETE DISABLE: Welcome, Update Manager, Power Timeout ===
# Run as USER (gsettings needs this), REBOOT after

USER="$(whoami)"

# 2. UPDATE MANAGER - ALL VARIANTS (system + user)
echo "disabling update autostart"
# Add or update the 'enabled' flag to false
if grep -q "X-GNOME-Autostart-enabled" /etc/xdg/autostart/mintupdate.desktop; then
    sudo sed -i 's/X-GNOME-Autostart-enabled=true/X-GNOME-Autostart-enabled=false/g' /etc/xdg/autostart/mintupdate.desktop
else
    echo "X-GNOME-Autostart-enabled=false" | sudo tee -a /etc/xdg/autostart/mintupdate.desktop
fi

# 4. POWER TIMEOUT - CINNAMON + SYSTEMD (both needed)
# Cinnamon gsettings (primary)
echo "removing time limit"
gsettings set org.cinnamon.desktop.session idle-delay 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-battery 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0

# 5. Install AnyDesk (modern keyring method)
ANYDESK_KEY_URL="https://keys.anydesk.com/repos/DEB-GPG-KEY"
ANYDESK_LIST="/etc/apt/sources.list.d/anydesk-stable.list"
ANYDESK_KEYRING="/usr/share/keyrings/anydesk.gpg"

wget -qO- "$ANYDESK_KEY_URL" | gpg --dearmor | sudo tee "$ANYDESK_KEYRING" >/dev/null
echo "deb [signed-by=$ANYDESK_KEYRING] http://deb.anydesk.com/ all main" | sudo tee "$ANYDESK_LIST"
sudo apt update
sudo apt install -y anydesk

# 6. Start AnyDesk service and wait for it to be ready
echo "Starting AnyDesk service..."
sudo systemctl start anydesk.service
sleep 5  # give it a moment to come up

ANYDESK_ID=$(anydesk --get-id 2>/dev/null || true)
if [[ -z "$ANYDESK_ID" || "$ANYDESK_ID" == "SERVICE_NOT_RUNNING" ]]; then
    echo "AnyDesk service not ready yet; starting AnyDesk manually..."
    anydesk --service &
    sleep 3
    ANYDESK_ID=$(anydesk --get-id 2>/dev/null || true)
fi

if [[ -n "$ANYDESK_ID" && "$ANYDESK_ID" != "SERVICE_NOT_RUNNING" ]]; then
    echo "AnyDesk client ID: $ANYDESK_ID"
	echo "your_secure_password_here" | sudo anydesk --set-password 
else
    echo "WARNING: could not retrieve AnyDesk ID; run 'anydesk --get-id' manually after first GUI launch."
fi


echo "=== DONE. REBOOT NOW ==="
echo "Verify after reboot:"
echo "  Power Manager → 'Never' (all timeouts)"
echo "  Startup Apps → No mintupdate/mintwelcome"
echo "  gsettings get org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout  # uint32 0"
