#!/bin/bash

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
name="$(date +%Y%m%d_%H%M%S).png"

SATTY_OPTS=(--output-filename "$dir/$name" --actions-on-escape "save-to-clipboard,save-to-file,exit" --copy-command wl-copy)

case "$1" in
    full)
        grim - | satty --filename - "${SATTY_OPTS[@]}"
        ;;
    region)
        grim -g "$(slurp)" - | satty --filename - "${SATTY_OPTS[@]}"
        ;;
    window)
        grim -g "$(hyprctl activewindow -j | jq -r '.at | join(",")') $(hyprctl activewindow -j | jq -r '.size | join(",")')" - | satty --filename - "${SATTY_OPTS[@]}"
        ;;
esac

# Make the screenshot immediately pasteable. wl-copy runs detached so the
# keybind returns at once while it serves as the clipboard owner; wl-clip-persist
# then keeps the image alive after this process exits.
wl-copy --type image/png < "$dir/$name" &

# Ensure the screenshot also lands in clipboard history (harmless if the
# background watcher already stored it — cliphist de-duplicates).
cliphist store < "$dir/$name" >/dev/null 2>&1
