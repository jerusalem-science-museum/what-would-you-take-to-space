#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "=== Kiosk Setup for Linux Mint (Cinnamon) ==="
echo "Project directory: $SCRIPT_DIR"
echo ""

# --- Collect passwords upfront ---
sudo -v
echo ""

read -sp "Enter the password you want for AnyDesk remote access: " ANYDESK_PASSWORD
echo ""

# =========================================================================
# 1. System packages
# =========================================================================
echo ""
echo "=== Installing system packages ==="
sudo apt update
sudo apt install -y python3 python3-venv python3-pip git unclutter netcat-openbsd curl ca-certificates

# =========================================================================
# 2. Chromium (package name varies across Mint versions)
# =========================================================================
echo ""
echo "=== Installing Chromium ==="
sudo apt install -y chromium-browser 2>/dev/null || sudo apt install -y chromium

# =========================================================================
# 3. Python venv & dependencies
# =========================================================================
echo ""
echo "=== Setting up Python environment ==="
python3 -m venv "$SCRIPT_DIR/.venv"
source "$SCRIPT_DIR/.venv/bin/activate"
pip install -r "$SCRIPT_DIR/requirements.txt"

# =========================================================================
# 4. Make scripts executable
# =========================================================================
chmod +x "$SCRIPT_DIR/run_app.sh" "$SCRIPT_DIR/fix_touch.sh"

# =========================================================================
# 5. AnyDesk
# =========================================================================
echo ""
echo "=== Installing AnyDesk ==="

# Download the .deb directly — avoids repo/GPG key issues entirely
ANYDESK_DEB="/tmp/anydesk.deb"
wget -O "$ANYDESK_DEB" "https://download.anydesk.com/linux/anydesk_7.1.4-1_amd64.deb" \
  || curl -fsSL -o "$ANYDESK_DEB" "https://download.anydesk.com/linux/anydesk_7.1.4-1_amd64.deb"
sudo apt install -y "$ANYDESK_DEB"
rm -f "$ANYDESK_DEB"

# Start service and set password
sudo systemctl enable anydesk.service
sudo systemctl start anydesk.service
sleep 3

echo "$ANYDESK_PASSWORD" | sudo anydesk --set-password

ANYDESK_ID=$(anydesk --get-id 2>/dev/null || echo "(not available yet)")
echo "AnyDesk ID: $ANYDESK_ID"

# =========================================================================
# 6. Disable Mint Welcome & Update Manager
# =========================================================================
echo ""
echo "=== Disabling Mint Welcome & Update Manager ==="

# System-level: flip the autostart flag
for DESKTOP_FILE in mintupdate.desktop mintwelcome.desktop; do
  FULL_PATH="/etc/xdg/autostart/$DESKTOP_FILE"
  if [ -f "$FULL_PATH" ]; then
    if grep -q "X-GNOME-Autostart-enabled" "$FULL_PATH"; then
      sudo sed -i 's/X-GNOME-Autostart-enabled=true/X-GNOME-Autostart-enabled=false/g' "$FULL_PATH"
    else
      echo "X-GNOME-Autostart-enabled=false" | sudo tee -a "$FULL_PATH" >/dev/null
    fi
  fi
done

# User-level override (belt and suspenders)
mkdir -p ~/.config/autostart
for DESKTOP_FILE in mintupdate.desktop mintwelcome.desktop; do
  cat > ~/.config/autostart/"$DESKTOP_FILE" << EOF
[Desktop Entry]
Hidden=true
X-GNOME-Autostart-enabled=false
EOF
done

# =========================================================================
# 7. Disable power/sleep timeouts (kiosk should never sleep)
# =========================================================================
echo ""
echo "=== Disabling power/sleep timeouts ==="
gsettings set org.cinnamon.desktop.session idle-delay 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-battery 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0

# =========================================================================
# 8. Touchscreen configuration (optional)
# =========================================================================
echo ""
read -rp "Configure touchscreen mapping? [y/N]: " CONFIGURE_TOUCH
CONFIGURE_TOUCH=${CONFIGURE_TOUCH,,}  # lowercase

if [[ "$CONFIGURE_TOUCH" == "y" ]]; then
  echo ""
  echo "--- xinput devices ---"
  xinput list
  echo ""
  echo "--- xrandr outputs ---"
  xrandr
  echo ""

  read -rp "Enter the touchscreen device name (from xinput list above): " TOUCH_DEVICE
  read -rp "Enter the display output name (from xrandr above): " DISPLAY_OUTPUT

  # Update fix_touch.sh with the user's values
  sed -i "s|^xinput map-to-output .*|xinput map-to-output \"$TOUCH_DEVICE\" $DISPLAY_OUTPUT|" "$SCRIPT_DIR/fix_touch.sh"

  echo "Updated fix_touch.sh → device=\"$TOUCH_DEVICE\", output=\"$DISPLAY_OUTPUT\""

  # Autostart entry for touch fix at login
  cat > ~/.config/autostart/to-space-touch.desktop << EOF
[Desktop Entry]
Type=Application
Name=To Space - Touch Fix
Exec=bash $SCRIPT_DIR/fix_touch.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

  # Cron job: run touch fix every minute (in case it resets)
  (crontab -l 2>/dev/null | grep -v "fix_touch"; echo "* * * * * DISPLAY=:0 bash $SCRIPT_DIR/fix_touch.sh") | crontab -
  echo "Touch fix will run at login and every minute via cron."
else
  echo "Skipping touchscreen configuration."
fi

# =========================================================================
# 9. Autostart: app + cursor hiding
# =========================================================================
echo ""
echo "=== Setting up autostart ==="
mkdir -p ~/.config/autostart

# App autostart
cat > ~/.config/autostart/to-space-app.desktop << EOF
[Desktop Entry]
Type=Application
Name=To Space - Flask + Kiosk
Exec=bash $SCRIPT_DIR/run_app.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Hide cursor after 2 seconds of inactivity
cat > ~/.config/autostart/unclutter.desktop << EOF
[Desktop Entry]
Type=Application
Name=Hide Cursor
Exec=unclutter -idle 2 -root
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# =========================================================================
# Done
# =========================================================================
echo ""
echo "========================================="
echo "  Setup complete! Reboot to apply."
echo "========================================="
echo ""
echo "After reboot, verify:"
echo "  - App launches in kiosk mode automatically"
echo "  - Cursor disappears after 2 seconds"
if [[ "$CONFIGURE_TOUCH" == "y" ]]; then
  echo "  - Touch fix runs every minute (crontab -l)"
fi
echo "  - No update/welcome popups"
echo "  - AnyDesk ID: $ANYDESK_ID"
echo ""
echo "Rebooting now is recommended: sudo reboot"
