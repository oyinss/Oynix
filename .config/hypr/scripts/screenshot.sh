#!/bin/bash

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
name="$(date +%Y%m%d_%H%M%S).png"

case "$1" in
    full)
        grim "$dir/$name"
        ;;
    region)
        grim -g "$(slurp)" "$dir/$name"
        ;;
    window)
        grim -g "$(hyprctl activewindow -j | jq -r '.at | join(",")') $(hyprctl activewindow -j | jq -r '.size | join(",")')" "$dir/$name"
        ;;
esac

# Make the screenshot immediately pasteable. wl-copy runs detached so the
# keybind returns at once while it serves as the clipboard owner; wl-clip-persist
# then keeps the image alive after this process exits.
wl-copy --type image/png < "$dir/$name" &

# Ensure the screenshot also lands in clipboard history (harmless if the
# background watcher already stored it — cliphist de-duplicates).
cliphist store < "$dir/$name" >/dev/null 2>&1
