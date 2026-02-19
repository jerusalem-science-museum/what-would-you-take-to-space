#!/bin/bash
set -euo pipefail

echo "=== Kiosk Base Setup for Linux Mint (Cinnamon) ==="
echo ""

# --- Collect inputs upfront ---
sudo -v

read -sp "Enter AnyDesk password (or press Enter to skip): " ANYDESK_PASSWORD
echo ""
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
# 3. Add user to dialout group (for serial/USB access)
# =========================================================================
echo ""
echo "=== Adding $USER to dialout group ==="
sudo usermod -aG dialout "$USER"
echo "Done. Log out and back in (or reboot) for this to take effect."

# =========================================================================
# 4. AnyDesk
# =========================================================================
echo ""
echo "=== AnyDesk ==="

if command -v anydesk &>/dev/null; then
  echo "AnyDesk is already installed."
else
  echo "Installing AnyDesk..."
  ANYDESK_DEB="/tmp/anydesk.deb"
  wget -O "$ANYDESK_DEB" "https://download.anydesk.com/linux/anydesk_7.1.4-1_amd64.deb" \
    || curl -fsSL -o "$ANYDESK_DEB" "https://download.anydesk.com/linux/anydesk_7.1.4-1_amd64.deb"
  sudo apt install -y "$ANYDESK_DEB"
  rm -f "$ANYDESK_DEB"
fi

sudo systemctl enable anydesk.service
sudo systemctl start anydesk.service
sleep 3

ANYDESK_ID=$(anydesk --get-id 2>/dev/null || echo "(not available yet)")
echo "AnyDesk ID: $ANYDESK_ID"

if [[ -n "$ANYDESK_PASSWORD" ]]; then
  echo "$ANYDESK_PASSWORD" | sudo anydesk --set-password
  echo "AnyDesk password set."
else
  echo "Skipping AnyDesk password setup."
fi

# =========================================================================
# 5. Disable Mint Welcome & Update Manager
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
# 6. Disable power/sleep timeouts (kiosk should never sleep)
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
# 7. Autostart: hide cursor
# =========================================================================
echo ""
echo "=== Setting up unclutter (cursor hiding) autostart ==="
mkdir -p ~/.config/autostart

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
echo "  Base setup complete!"
echo "========================================="
echo ""
echo "What was done:"
echo "  [Packages]     Installed python3-venv, git, unclutter, curl, ca-certificates, netcat"
echo "  [Chromium]     Installed (will be used in kiosk mode)"
echo "  [Dialout]      Added $USER to dialout group (for serial/USB — takes effect after reboot)"
echo "  [AnyDesk]      Installed — ID: $ANYDESK_ID"
echo "  [Updates]      Disabled Mint Welcome and Update Manager autostart"
echo "  [Power]        Disabled all sleep/suspend/screen-off timeouts"
echo "  [Cursor]       Will hide after 2 seconds of inactivity (unclutter)"
echo ""
echo "Next steps:"
echo "  1. Clone your repo"
echo "  2. Run setup.sh from inside the repo directory"
echo "  3. Reboot (applies dialout group + all autostart changes)"
echo ""
echo "  sudo reboot"
