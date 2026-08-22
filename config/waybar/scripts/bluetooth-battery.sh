#!/usr/bin/env bash
# Waybar custom module: Bluetooth icon + connected device battery %.
# Uses bluetoothctl (connectivity + names) and upower (battery levels).

set -u

BLUETOOTH_ON=""
if command -v bluetoothctl >/dev/null 2>&1; then
    BLUETOOTH_ON="$(timeout 5 bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}')"
fi
[[ "$BLUETOOTH_ON" == "yes" ]] && BLUETOOTH_ON=yes || BLUETOOTH_ON=no

# Connected device mac addresses + aliases
CONNECTED=""
if command -v bluetoothctl >/dev/null 2>&1; then
    CONNECTED="$(timeout 8 bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')"
fi

# Build a map mac -> alias for all known devices
declare -A NAMES
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    mac="$(awk '{print $2}' <<<"$line")"
    name="$(awk '{for(i=3;i<=NF;i++) printf "%s%s",(i>3?" ":"") ,$i; print ""}' <<<"$line")"
    [[ -n "$mac" ]] && NAMES[$mac]="$name"
done <<< "$(timeout 8 bluetoothctl devices 2>/dev/null)"

text=""
tooltip=""
batteries=()
has_batt=0
connected_count=0
avg=0

if [[ "$BLUETOOTH_ON" == "no" ]]; then
    text=""
    tooltip="Bluetooth off"
    printf '{"text":"%s","tooltip":"%s","class":"bluetooth-off","percentage":0}\n' "$text" "$tooltip"
    exit 0
fi

# Collect battery percentages from upower for connected bluetooth devices
if command -v upower >/dev/null 2>&1; then
    while IFS= read -r mac; do
        [[ -z "$mac" ]] && continue
        connected_count=$((connected_count + 1))
        name="${NAMES[$mac]:-$mac}"
        pct="$(timeout 5 upower --dump 2>/dev/null | grep -iA16 "$mac" | awk '/percentage:/{gsub(/[^0-9]/,""); print; exit}')"
        if [[ -n "$pct" ]]; then
            batteries+=("$pct")
            has_batt=1
            tooltip+="$name: $pct%\n"
        else
            tooltip+="$name: no battery info\n"
        fi
    done <<< "$CONNECTED"
fi

if [[ $has_batt -eq 1 ]]; then
    # Average percentage across connected devices
    sum=0
    for p in "${batteries[@]}"; do sum=$((sum + p)); done
    avg=$((sum / ${#batteries[@]}))
    text=" $avg%"
    class="bluetooth-ok"
    if (( avg <= 20 )); then class="bluetooth-low"; fi
elif [[ $connected_count -gt 0 ]]; then
    text=""
    class="bluetooth-ok"
else
    text=""
    tooltip+="No devices connected"
    class="bluetooth-on"
fi

tooltip="${tooltip%\\n}"
printf '{"text":"%s","tooltip":"%s","class":"%s","percentage":%s}\n' "$text" "$tooltip" "$class" "$avg"
