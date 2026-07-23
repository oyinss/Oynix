#!/usr/bin/env bash
kitty --class kitty-float -o window_padding_width=4 &
KPID=$!
sleep 0.3
hyprctl dispatch focuswindow class:"kitty-float" 2>/dev/null
sleep 0.05
hyprctl dispatch setfloating 2>/dev/null
sleep 0.05
hyprctl dispatch resizeactive exact 720 450 2>/dev/null
hyprctl dispatch center 2>/dev/null
