#!/usr/bin/env bash
# Rofi clipboard manager with image previews.
# Lists cliphist history in rofi; text entries show inline, image entries
# show a thumbnail. Selecting an entry copies it back to the clipboard.
set -u

theme="$HOME/.config/rofi/launchers/clipboard.rasi"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-clipboard"
mkdir -p "$cache/thumbs"

# Toggle: close rofi if already open, otherwise open the clipboard menu.
if pgrep -x rofi > /dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

declare -a ids
entries=""
while IFS=$'\t' read -r id content; do
    [[ -n "$id" ]] || continue
    ids+=("$id")
    if [[ "$content" == "[[ binary data"* ]]; then
        # Image entry: generate (and cache) a thumbnail used as the rofi icon.
        thumb="$cache/thumbs/$id.png"
        if [[ ! -f "$thumb" ]]; then
            cliphist decode "$id" 2>/dev/null \
                | convert - -resize 96x96\> "$thumb" 2>/dev/null || rm -f "$thumb"
        fi
        dims=$(grep -oE '[0-9]+x[0-9]+' <<<"$content" | head -n 1)
        if [[ -f "$thumb" ]]; then
            entries+="Image ${dims:-}\0icon\x1f$thumb\n"
        else
            entries+="Image ${dims:-}\n"
        fi
    else
        entries+="$content\n"
    fi
done < <(cliphist list)

[[ -z "$entries" ]] && exit 0

sel=$(printf '%b' "$entries" \
    | rofi -dmenu -show-icons -i -p "Clipboard" -theme "$theme" -format i)

if [[ "$sel" =~ ^[0-9]+$ && "$sel" -lt "${#ids[@]}" ]]; then
    cliphist decode "${ids[$sel]}" | wl-copy
fi
