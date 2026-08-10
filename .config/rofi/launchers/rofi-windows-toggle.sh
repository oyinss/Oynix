#!/usr/bin/env bash
# Toggle the window switcher bound to SUPER+W.
# Uses the Hyprland-native window list (rofi-windows.sh) because Rofi's
# built-in "window" mode relies on X11 EWMH (_NET_ACTIVE_WINDOW) and cannot
# focus windows on Hyprland (Wayland).
dir="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/launchers"
if pgrep -x rofi > /dev/null 2>&1; then
    pkill -x rofi
else
    "$dir/rofi-windows.sh"
fi
