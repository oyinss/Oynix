#!/bin/bash

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
name="$(date +%Y%m%d_%H%M%S).png"

clip() {
    wl-copy --type image/png < "$dir/$name" &
    cliphist store < "$dir/$name" >/dev/null 2>&1
}

case "$1" in
    full)
        grim "$dir/$name" && clip
        ;;
    region)
        grim -g "$(slurp)" "$dir/$name" && clip
        ;;
    window)
        grim -g "$(hyprctl activewindow -j | jq -r '.at | join(",")') $(hyprctl activewindow -j | jq -r '.size | join(",")')" "$dir/$name" && clip
        ;;
    region-satty)
        grim -g "$(slurp)" - | satty --filename - --output-filename "$dir/$name" --actions-on-escape "save-to-clipboard,save-to-file,exit" --copy-command wl-copy
        clip
        ;;
esac
