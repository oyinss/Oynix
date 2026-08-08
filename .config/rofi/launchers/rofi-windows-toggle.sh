#!/usr/bin/env bash
# Toggle the window switcher bound to SUPER+W.
# Opens the shared multi-mode rofi (drun / window / run) starting on the
# window list, so the mode tabs stay visible like the app menu (SUPER+A).
if pgrep -x rofi > /dev/null 2>&1; then
    pkill -x rofi
else
    rofi -show window -show-icons -theme "$HOME/.config/rofi/launchers/clipboard.rasi"
fi
