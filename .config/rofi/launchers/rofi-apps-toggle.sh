#!/usr/bin/env bash
# Toggle the application launcher bound to SUPER+A:
# open it if closed, close it if already open.
if pgrep -x rofi > /dev/null 2>&1; then
    pkill -x rofi
else
    rofi -show drun -theme "$HOME/.config/rofi/launchers/launcher.rasi"
fi
