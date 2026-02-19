#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "=== Kiosk App Setup ==="
echo "Project directory: $SCRIPT_DIR"
echo "(Run kiosk-base-setup.sh first on a fresh machine if you haven't already.)"
echo ""

# =========================================================================
# 1. Python venv & dependencies
# =========================================================================
echo ""
echo "=== Setting up Python environment ==="
python3 -m venv "$SCRIPT_DIR/.venv"
source "$SCRIPT_DIR/.venv/bin/activate"
pip install -r "$SCRIPT_DIR/requirements.txt"

# =========================================================================
# 2. Make scripts executable
# =========================================================================
chmod +x "$SCRIPT_DIR/run_app.sh" "$SCRIPT_DIR/fix_touch.sh"

# =========================================================================
# 3. Touchscreen configuration (optional)
# =========================================================================
echo ""
read -rp "Configure touchscreen mapping? [y/N]: " CONFIGURE_TOUCH
CONFIGURE_TOUCH=${CONFIGURE_TOUCH,,}  # lowercase

if [[ "$CONFIGURE_TOUCH" == "y" ]]; then
  echo ""
  echo "--- xinput devices ---"
  xinput list
  echo ""
  read -rp "Enter the touchscreen device name (from the list above): " TOUCH_DEVICE

  echo ""
  echo "--- xrandr outputs ---"
  xrandr
  echo ""
  read -rp "Enter the display output name (from the list above): " DISPLAY_OUTPUT

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
# 4. Autostart: app
# =========================================================================
echo ""
echo "=== Setting up app autostart ==="
mkdir -p ~/.config/autostart

cat > ~/.config/autostart/to-space-app.desktop << EOF
[Desktop Entry]
Type=Application
Name=To Space - Flask + Kiosk
Exec=bash $SCRIPT_DIR/run_app.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# =========================================================================
# Done
# =========================================================================
echo ""
echo "========================================="
echo "  App setup complete! Reboot to apply."
echo "========================================="
echo ""
echo "What was done:"
echo "  [Python]       Created .venv and installed Flask + wordcloud"
echo "  [App]          Will auto-launch Flask + Chromium kiosk on login"
if [[ "$CONFIGURE_TOUCH" == "y" ]]; then
  echo "  [Touchscreen]  Configured and will re-apply every minute via cron"
else
  echo "  [Touchscreen]  Skipped — run setup again to configure later"
fi
echo ""
echo "Rebooting now is recommended: sudo reboot"
