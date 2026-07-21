#!/bin/bash

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
name="$(date +%Y%m%d_%H%M%S).png"

case "$1" in
    full)
        grim - | tee "$dir/$name" | cliphist store | wl-copy
        ;;
    region)
        grim -g "$(slurp)" - | tee "$dir/$name" | cliphist store | wl-copy
        ;;
    window)
        grim -g "$(hyprctl activewindow -j | jq -r '.at | join(",")') $(hyprctl activewindow -j | jq -r '.size | join(",")')" - | tee "$dir/$name" | cliphist store | wl-copy
        ;;
esac
