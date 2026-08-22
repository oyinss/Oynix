#!/bin/sh

direction="$1"
case "$direction" in
  rx) icon="" ;;
  tx) icon="" ;;
  *) exit 1 ;;
esac

interface=$(ip -4 route get 1.1.1.1 2>/dev/null \
  | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

counter_file="/sys/class/net/$interface/statistics/${direction}_bytes"
if [ -z "$interface" ] || [ ! -r "$counter_file" ]; then
  printf '{"text":"%s offline","class":"disconnected"}\n' "$icon"
  exit 0
fi

runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
state_file="$runtime_dir/waybar-network-speed-$direction"
now_ms=$(date +%s%3N)
current_bytes=$(cat "$counter_file")
rate=0

if [ -r "$state_file" ]; then
  read -r previous_interface previous_ms previous_bytes < "$state_file"
  elapsed_ms=$((now_ms - previous_ms))
  transferred=$((current_bytes - previous_bytes))

  if [ "$previous_interface" = "$interface" ] \
    && [ "$elapsed_ms" -gt 0 ] \
    && [ "$transferred" -ge 0 ]; then
    rate=$((transferred * 1000 / elapsed_ms))
  fi
fi

printf '%s %s %s\n' "$interface" "$now_ms" "$current_bytes" > "$state_file"

if [ "$rate" -ge 1000000 ]; then
  speed=$(awk -v bytes="$rate" 'BEGIN { printf "%.1f MB/s", bytes / 1000000 }')
  class="megabytes"
elif [ "$rate" -ge 1000 ]; then
  speed=$(awk -v bytes="$rate" 'BEGIN { printf "%.0f KB/s", bytes / 1000 }')
  class="kilobytes"
else
  speed="$rate B/s"
  class="normal"
fi

printf '{"text":"%s %s","class":"%s"}\n' "$icon" "$speed" "$class"
