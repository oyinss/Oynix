#!/usr/bin/env bash
# Temporarily disable touchpad for N seconds (default: 10)

TIMEOUT="${1:-10}"
LOCKFILE="/tmp/touchpad-disable.lock"

# Find touchpad device name
DEVICE=$(hyprctl devices -j 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for m in d.get('mice', []):
    if 'touchpad' in m.get('name', '').lower():
        print(m['name'])
        break
" 2>/dev/null)

if [ -z "$DEVICE" ]; then
    echo "No touchpad found" >&2
    exit 1
fi

# If already disabled, just extend the timer
if [ -f "$LOCKFILE" ]; then
    kill "$(cat "$LOCKFILE")" 2>/dev/null
fi

# Disable touchpad
hyprctl keyword "device[$DEVICE]:enabled false" >/dev/null 2>&1 &

# Background timer to re-enable
(
    sleep "$TIMEOUT"
    hyprctl keyword "device[$DEVICE]:enabled true" >/dev/null 2>&1 &
    rm -f "$LOCKFILE"
) &
echo $! > "$LOCKFILE"
