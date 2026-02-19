#!/bin/bash

# Maps the touchscreen input device to the correct display output.
#
# If the touch coordinates are offset or mapped to the wrong screen, update
# the two arguments below:
#
#   Argument 1 — xinput device name:
#     Run `xinput list` to see all connected input devices.
#     Look for your touchscreen (e.g. "USBest Technology SiS HID Touch Controller").
#     You can use the device name string or its numeric ID.
#
#   Argument 2 — display output name:
#     Run `xrandr` to see all connected outputs (e.g. HDMI1, HDMI2, eDP1, DP-1).
#     Use whichever output the touchscreen is physically connected to.

xinput map-to-output "USBest Technology SiS HID Touch Controller" HDMI2
