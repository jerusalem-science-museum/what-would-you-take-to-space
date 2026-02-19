#!/bin/bash

# Resolve the directory this script lives in (no hardcoded paths)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

source .venv/bin/activate

# Start Flask app in background
nohup flask run > flask.log 2>&1 &

# Wait for port 5000 to be available
echo "Waiting for Flask app to start on port 5000..."
until nc -z localhost 5000; do
  sleep 1
done
echo "Flask app is ready!"

# Detect which chromium binary is available
CHROMIUM_CMD=""
if command -v chromium-browser &>/dev/null; then
  CHROMIUM_CMD="chromium-browser"
elif command -v chromium &>/dev/null; then
  CHROMIUM_CMD="chromium"
else
  echo "ERROR: Chromium not found!"
  exit 1
fi

$CHROMIUM_CMD \
  --kiosk \
  --password-store=basic \
  --no-sandbox \
  --disable-pinch \
  --disable-dev-shm-usage \
  --disable-gpu-sandbox \
  --disable-background-timer-throttling \
  http://localhost:5000 &
