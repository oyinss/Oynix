#!/usr/bin/env bash

# Keep Waybar's Wi-Fi percentage identical to the zsh `net` function:
# read the current nl80211 dBm value and apply Waybar's -90..-20 clamp.
wifi_iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
  awk -F: '$2 == "wifi" && $3 == "connected" {print $1; exit}')

if [[ -n "$wifi_iface" ]]; then
  link=$(iw dev "$wifi_iface" link 2>/dev/null)
  signal_dbm=$(awk '/signal:/{print int($2); exit}' <<<"$link")
  ssid=$(sed -n 's/^[[:space:]]*SSID: //p' <<<"$link" | head -1)

  if [[ -n "$signal_dbm" ]]; then
    strength_dbm=$signal_dbm
    (( strength_dbm > -20 )) && strength_dbm=-20
    (( strength_dbm < -90 )) && strength_dbm=-90
    strength=$(( strength_dbm + 120 ))

    if (( signal_dbm >= -30 )); then
      quality="Excellent"
    elif (( signal_dbm >= -50 )); then
      quality="Very good"
    elif (( signal_dbm >= -60 )); then
      quality="Good"
    elif (( signal_dbm >= -70 )); then
      quality="Weak"
    else
      quality="Poor"
    fi

    tooltip=$(printf '%s\n%s\n\n%s\n%s\n%s\n%s\n%s\n%s' \
      "Network: ${ssid}" \
      "Signal: ${strength}% (${signal_dbm} dBm — ${quality})" \
      "Signal quality guide" \
      "-30 dBm: Excellent" \
      "-50 dBm: Very good" \
      "-60 dBm: Good" \
      "-70 dBm: Weak" \
      "-80 dBm: Poor")

    jq -cn \
      --arg text " ${strength}%" \
      --arg tooltip "$tooltip" \
      '{text: $text, tooltip: $tooltip, class: "connected"}'
    exit
  fi
fi

ethernet_iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
  awk -F: '$2 == "ethernet" && $3 == "connected" {print $1; exit}')

if [[ -n "$ethernet_iface" ]]; then
  ipaddr=$(ip -4 -o addr show dev "$ethernet_iface" 2>/dev/null | awk '{print $4; exit}')
  jq -cn \
    --arg tooltip "  ${ethernet_iface} (${ipaddr:-no IPv4 address})" \
    '{text: "  Wired", tooltip: $tooltip, class: "connected"}'
elif [[ $(nmcli radio wifi 2>/dev/null) == "disabled" ]]; then
  jq -cn '{text: "⚠  Disabled", tooltip: "Wi-Fi disabled", class: "disabled"}'
else
  jq -cn '{text: "⚠  Disconnected", tooltip: "Disconnected", class: "disconnected"}'
fi
