#!/bin/zsh

# Network aliases

ip-show() {
  ip route get 1.1.1.1 | awk '{print $7}'
}

# Local IP
if [[ -x "$(command -v ip)" ]]; then
    alias iplocal="ip -br -c a"
else
    alias iplocal="ifconfig | grep -Eo 'inet (addr:)?([0-9]*\\.){3}[0-9]*' | grep -Eo '([0-9]*\\.){3}[0-9]*' | grep -v '127.0.0.1'"
fi

# Public IP
if [[ -x "$(command -v curl)" ]]; then
    alias ipexternal="curl -s ifconfig.me && echo"
elif [[ -x "$(command -v wget)" ]]; then
    alias ipexternal="wget -qO- ifconfig.me && echo"
fi

# ===========================
# NetworkManager Interactive Manager
# Provides an nm fzf menu to scan, connect, disconnect, and manage Wi-Fi.
# Saved connections reconnect without password. New ones prompt for it.
# Usage: source this file then run nm to pick actions
# ===========================

net() {
  local red=$'\033[38;5;203m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local cyan=$'\033[38;5;80m'
  local blue=$'\033[38;5;75m'
  local purple=$'\033[38;5;141m'
  local orange=$'\033[38;5;208m'
  local dim=$'\033[38;5;243m'
  local bold=$'\033[1m'
  local reset=$'\033[0m'

  # Signal strength bars
  signal_bars() {
    local sig=$1
    if   (( sig >= 80 )); then echo -n "${green}\xe2\x94\x82\xe2\x94\x84\xe2\x94\x86\xe2\x94\x88${reset}"
    elif (( sig >= 60 )); then echo -n "${green}\xe2\x94\x82\xe2\x94\x84\xe2\x94\x86${reset}${dim}\xe2\x94\x88${reset}"
    elif (( sig >= 40 )); then echo -n "${yellow}\xe2\x94\x82\xe2\x94\x84${reset}${dim}\xe2\x94\x86\xe2\x94\x88${reset}"
    elif (( sig >= 20 )); then echo -n "${orange}\xe2\x94\x82${reset}${dim}\xe2\x94\x84\xe2\x94\x86\xe2\x94\x88${reset}"
    else                       echo -n "${red}${dim}\xe2\x94\x82\xe2\x94\x84\xe2\x94\x86\xe2\x94\x88${reset}"
    fi
  }

  # Security icon
  security_icon() {
    local sec="$1"
    if [[ "$sec" == *"WPA3"* ]]; then
      echo -n "${cyan}󰌾${reset}"
    elif [[ "$sec" == *"WPA2"* || "$sec" == *"WPA"* ]]; then
      echo -n "${yellow}󰌾${reset}"
    elif [[ "$sec" == *"WEP"* ]]; then
      echo -n "${orange}󰌾${reset}"
    elif [[ "$sec" == *"--"* || -z "$sec" ]]; then
      echo -n "${red}󰈂${reset}"
    else
      echo -n "${cyan}󰌾${reset}"
    fi
  }

  # Spinner animation
  spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=1
    local len=${#spinstr}
    while kill -0 "$pid" 2>/dev/null; do
      local ch="${spinstr[$(( i % len + 1 ))]}"
      printf "\r  ${cyan}${ch}${reset} ${dim}Scanning for networks...${reset}"
      sleep "$delay"
      (( i++ ))
    done
    printf "\r${reset}"
  }

  # Scan and pick a network
  scan_networks() {
    setopt localoptions nonotify

    local tmpfile
    tmpfile=$(mktemp)
    nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list > "$tmpfile" 2>/dev/null &
    local scan_pid=$!
    spinner "$scan_pid"
    local raw
    raw=$(<"$tmpfile")
    rm -f "$tmpfile"

    if [[ -z "$raw" ]]; then
      echo "${red}No networks found. Is Wi-Fi enabled?${reset}"
      return 1
    fi

    local -a entries=()
    local bars sec_icon tag saved_tag saved_name ssid signal sec inuse

    # Pre-compute saved connections: ssid->name map
    local -A saved_map
    local saved_tmp saved_line conn_type conn_ssid
    saved_tmp=$(mktemp)
    nmcli -t -f NAME connection show > "$saved_tmp" 2>/dev/null
    while IFS= read -r saved_line; do
      conn_type=$(nmcli -g TYPE connection show "$saved_line" 2>/dev/null)
      [[ "$conn_type" != "802-11-wireless" ]] && continue
      conn_ssid=$(nmcli -g 802-11-wireless.ssid connection show "$saved_line" 2>/dev/null)
      [[ -n "$conn_ssid" ]] && saved_map[$conn_ssid]="$saved_line"
    done < "$saved_tmp"
    rm -f "$saved_tmp"

    # Calculate the active link exactly as Waybar does from nl80211 dBm.
    # nmcli's scan list can lag behind the current link measurement.
    local wifi_iface connected_dbm connected_signal
    wifi_iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
      awk -F: '$2 == "wifi" && $3 == "connected" {print $1; exit}')
    if [[ -n "$wifi_iface" ]]; then
      connected_dbm=$(iw dev "$wifi_iface" link 2>/dev/null | awk '/signal:/{print int($2); exit}')
      if [[ -n "$connected_dbm" ]]; then
        (( connected_dbm > -20 )) && connected_dbm=-20
        (( connected_dbm < -90 )) && connected_dbm=-90
        connected_signal=$(( connected_dbm + 120 ))
      fi
    fi

    while IFS=: read -r ssid signal sec inuse; do
      [[ -z "$ssid" ]] && continue

      local display_signal=$signal
      [[ "$inuse" == "*" && -n "$connected_signal" ]] && display_signal=$connected_signal

      # Signal bars inline
      if   (( display_signal >= 80 )); then bars="${green}▄▆█${reset}"
      elif (( display_signal >= 60 )); then bars="${green}▂▄▆${reset}${dim}█${reset}"
      elif (( display_signal >= 40 )); then bars="${yellow}▂▄${reset}${dim}▆█${reset}"
      elif (( display_signal >= 20 )); then bars="${orange}▂${reset}${dim}▆█${reset}"
      else                           bars="${red}${dim}▂▄▆█${reset}"
      fi

      # Security icon inline
      case "$sec" in
        *WPA3*) sec_icon="${cyan}󰌾${reset}" ;;
        *WPA2*|*WPA*) sec_icon="${yellow}󰌾${reset}" ;;
        *WEP*) sec_icon="${orange}󰌾${reset}" ;;
        *"--"*) sec_icon="${red}󰈂${reset}" ;;
        *) sec_icon="${cyan}󰌾${reset}" ;;
      esac

      tag=""
      [[ "$inuse" == "*" ]] && tag=" ${green}(connected)${reset}"
      saved_tag=""
      saved_name="${saved_map[$ssid]}"
      [[ -n "$saved_name" ]] && saved_tag=" ${dim}[saved: $saved_name]${reset}"

      entries+=("${bars} ${sec_icon} ${bold}${ssid}${reset}${saved_tag}${tag} ${dim}| ${display_signal}% | ${sec}${reset}")
    done <<< "$raw"

    if [[ ${#entries[@]} -eq 0 ]]; then
      echo "${red}No visible networks.${reset}"
      return 1
    fi

    local choice
    choice=$(printf "%s\n" "${entries[@]}" | command fzf \
      --ansi \
      --no-preview \
      --height=50% \
      --reverse \
      --prompt "Select network > " \
      --border \
      --header "󰤨 Available Wi-Fi Networks (Ctrl-R to rescan)" \
      --bind "ctrl-r:reload(echo '  󰤨 Rescanning...' && nmcli device wifi rescan 2>/dev/null && sleep 2 && nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list)" 2>/dev/null)

    [[ -z "$choice" ]] && return

    # Strip ANSI codes and extract the SSID
    local stripped
    stripped=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

    # Format: bars sec_icon SSID [saved: name] [(connected)] | signal% | sec
    local selected_ssid
    selected_ssid=$(echo "$stripped" | sed 's/^[^ ]* [^ ]* //' | sed 's/ \[saved:.*//' | sed 's/ (connected)//' | sed 's/ .*//' | xargs)

    [[ -z "$selected_ssid" ]] && return

    connect_to_network "$selected_ssid"
  }

  # Connect to a given SSID
  connect_to_network() {
    local ssid="$1"
    echo "${cyan}Connecting to: ${bold}${ssid}${reset}"

    # Check if there is a saved connection
    local saved_name conn_type conn_ssid
    local conn_tmp conn
    conn_tmp=$(mktemp)
    nmcli -t -f NAME connection show > "$conn_tmp" 2>/dev/null
    while IFS= read -r conn; do
      conn_type=$(nmcli -g TYPE connection show "$conn" 2>/dev/null)
      [[ "$conn_type" != "802-11-wireless" ]] && continue
      conn_ssid=$(nmcli -g 802-11-wireless.ssid connection show "$conn" 2>/dev/null)
      if [[ "$conn_ssid" == "$ssid" ]]; then
        saved_name="$conn"
        break
      fi
    done < "$conn_tmp"
    rm -f "$conn_tmp"

    if [[ -n "$saved_name" ]]; then
      echo "${dim}Using saved connection: ${saved_name}${reset}"
      if nmcli connection up "$saved_name" 2>/dev/null; then
        echo "${green}Connected to ${bold}${ssid}${reset}"
        show_connection_summary "$ssid"
      else
        echo "${red}Failed to connect. Password may have changed. Try forgetting and reconnecting.${reset}"
      fi
    else
      echo "${yellow}New network - password required.${reset}"
      read -rs "password?Enter password for '${ssid}': "
      echo

      if [[ -z "$password" ]]; then
        echo "${red}No password provided. Aborting.${reset}"
        return 1
      fi

      if nmcli device wifi connect "$ssid" password "$password" 2>/dev/null; then
        echo "${green}Connected to ${bold}${ssid}${reset} ${dim}(saved for future use)${reset}"
        show_connection_summary "$ssid"
      else
        echo "${red}Connection failed. Check password and try again.${reset}"
      fi
    fi
  }

  # Show brief connection summary
  show_connection_summary() {
    local ssid="$1"
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')
    local iface
    iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep ':wifi' | cut -d: -f1 | head -1)
    local speed=""
    if [[ -n "$iface" && -f "/sys/class/net/$iface/speed" ]]; then
      speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null)
      [[ "$speed" == "-1" ]] && speed=""
    fi

    echo
    echo "  ${blue}+-----------------------------------+${reset}"
    echo "  ${blue}|${reset}  󰈀 ${bold}Connected${reset}"
    [[ -n "$ssid" ]]  && echo "  ${blue}|${reset}  󰇀  SSID:   ${cyan}${ssid}${reset}"
    [[ -n "$ip" ]]    && echo "  ${blue}|${reset}  󰈂  IP:     ${green}${ip}${reset}"
    [[ -n "$iface" ]] && echo "  ${blue}|${reset}  󰖟  Device: ${purple}${iface}${reset}"
    [[ -n "$speed" ]] && echo "  ${blue}|${reset}   Speed:  ${orange}${speed} Mb/s${reset}"
    echo "  ${blue}+-----------------------------------+${reset}"
  }

  # Show current connection
  show_current() {
    local active
    active=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | grep 'wireless' | head -1)

    if [[ -z "$active" ]]; then
      echo "${yellow}No active Wi-Fi connection.${reset}"
      return
    fi

    local name
    name=$(echo "$active" | cut -d: -f1)
    local iface
    iface=$(echo "$active" | cut -d: -f3)
    local ssid
    ssid=$(nmcli -g 802-11-wireless.ssid connection show "$name" 2>/dev/null)
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')
    local freq
    freq=$(nmcli -f frequency connection show "$name" 2>/dev/null | awk '{print $1}')
    local speed=""
    if [[ -n "$iface" && -f "/sys/class/net/$iface/speed" ]]; then
      speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null)
      [[ "$speed" == "-1" ]] && speed=""
    fi

    echo
    echo "  ${blue}+-------------------------------------------+${reset}"
    echo "  ${blue}|${reset}  󰈀 ${bold}Active Wi-Fi Connection${reset}"
    [[ -n "$ssid" ]]   && echo "  ${blue}|${reset}  󰇀  SSID:      ${cyan}${ssid}${reset}"
    [[ -n "$name" ]]   && echo "  ${blue}|${reset}  󰑌  Profile:   ${purple}${name}${reset}"
    [[ -n "$ip" ]]     && echo "  ${blue}|${reset}  󰈂  IP:        ${green}${ip}${reset}"
    [[ -n "$iface" ]]  && echo "  ${blue}|${reset}  󰖟  Device:    ${purple}${iface}${reset}"
    [[ -n "$freq" ]]   && echo "  ${blue}|${reset}  󰈈  Frequency: ${orange}${freq} MHz${reset}"
    [[ -n "$speed" ]]  && echo "  ${blue}|${reset}   Speed:     ${orange}${speed} Mb/s${reset}"
    echo "  ${blue}+-------------------------------------------+${reset}"
  }

  # Disconnect
  disconnect_wifi() {
    local iface
    iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep ':wifi' | cut -d: -f1 | head -1)
    if [[ -z "$iface" ]]; then
      echo "${yellow}No Wi-Fi device found.${reset}"
      return
    fi

    local active
    active=$(nmcli -t -f NAME connection show --active 2>/dev/null | grep -v 'lo\|ethernet' | head -1)
    if [[ -z "$active" ]]; then
      echo "${yellow}Nothing connected.${reset}"
      return
    fi

    nmcli device disconnect "$iface" 2>/dev/null
    echo "${green}Disconnected from ${bold}${active}${reset}"
  }

  # Forget a saved network
  forget_network() {
    local -a conn_names=()
    while IFS= read -r name; do
      local type
      type=$(nmcli -g TYPE connection show "$name" 2>/dev/null)
      if [[ "$type" == "802-11-wireless" ]]; then
        local ssid
        ssid=$(nmcli -g 802-11-wireless.ssid connection show "$name" 2>/dev/null)
        conn_names+=("${cyan}${ssid}${reset} ${dim}(${name})${reset}")
      fi
    done < <(nmcli -t -f NAME connection show 2>/dev/null)

    if [[ ${#conn_names[@]} -eq 0 ]]; then
      echo "${yellow}No saved Wi-Fi connections.${reset}"
      return
    fi

    local choice
    choice=$(printf "%s\n" "${conn_names[@]}" | command fzf \
      --ansi \
      --no-preview \
      --height=30% \
      --reverse \
      --prompt "Forget network > " \
      --header "󰆴 Select network to forget" 2>/dev/null)

    [[ -z "$choice" ]] && return

    local conn_name
    conn_name=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g' | sed 's/.*(\(.*\))/\1/')

    read "confirm?Forget '${conn_name}'? [y/N]: "
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      nmcli connection delete "$conn_name" 2>/dev/null
      echo "${green}Forgotten: ${bold}${conn_name}${reset}"
    else
      echo "${dim}Cancelled.${reset}"
    fi
  }

  # Toggle Wi-Fi radio
  toggle_wifi() {
    local state
    state=$(nmcli -t -f WIFI general 2>/dev/null)
    if [[ "$state" == "enabled" ]]; then
      nmcli radio wifi off 2>/dev/null
      echo "${red}Wi-Fi disabled${reset}"
    else
      nmcli radio wifi on 2>/dev/null
      echo "${green}Wi-Fi enabled${reset}"
      sleep 1
      echo "${dim}Scanning...${reset}"
    fi
  }

  # List saved connections
  list_saved() {
    local -a saved=()
    while IFS= read -r name; do
      local type ssid
      type=$(nmcli -g TYPE connection show "$name" 2>/dev/null)
      [[ "$type" != "802-11-wireless" ]] && continue
      ssid=$(nmcli -g 802-11-wireless.ssid connection show "$name" 2>/dev/null)
      local sec
      sec=$(nmcli -g 802-11-wireless.key-mgmt connection show "$name" 2>/dev/null)
      local sec_label="${sec:-open}"
      saved+=("${cyan}${ssid}${reset}  ${dim}| ${sec_label} | ${name}${reset}")
    done < <(nmcli -t -f NAME connection show 2>/dev/null)

    if [[ ${#saved[@]} -eq 0 ]]; then
      echo "${yellow}No saved Wi-Fi connections.${reset}"
      return
    fi

    printf "%s\n" "${saved[@]}" | command fzf \
      --ansi \
      --no-preview \
      --height=40% \
      --reverse \
      --prompt "Saved networks > " \
      --header "󰑌 Saved Wi-Fi Connections" 2>/dev/null
  }

  # Create a hotspot
  create_hotspot() {
    read "hs_ssid?Hotspot name: "
    [[ -z "$hs_ssid" ]] && { echo "${red}Cancelled.${reset}"; return; }

    read -rs "hs_pass?Hotspot password (min 8 chars): "
    echo
    if [[ ${#hs_pass} -lt 8 ]]; then
      echo "${red}Password must be at least 8 characters.${reset}"
      return
    fi

    echo "${cyan}Creating hotspot '${hs_ssid}'...${reset}"
    if nmcli device wifi hotspot ifname wlan0 ssid "$hs_ssid" password "$hs_pass" 2>/dev/null; then
      echo "${green}Hotspot '${hs_ssid}' is live${reset}"
      local ip
      ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')
      [[ -n "$ip" ]] && echo "${dim}  IP: ${ip}${reset}"
    else
      echo "${red}Failed to create hotspot.${reset}"
    fi
  }

  # Show connection speed
  show_speed() {
    local iface
    iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep ':wifi' | cut -d: -f1 | head -1)
    if [[ -z "$iface" ]]; then
      echo "${yellow}No Wi-Fi device found.${reset}"
      return
    fi

    local speed_file="/sys/class/net/$iface/speed"
    if [[ -f "$speed_file" ]]; then
      local speed
      speed=$(cat "$speed_file" 2>/dev/null)
      if [[ "$speed" == "-1" || -z "$speed" ]]; then
        echo "${yellow}Speed unavailable (driver does not report link speed).${reset}"
        echo "${dim}Try: iw dev ${iface} link${reset}"
      else
        echo "${green}Link speed: ${bold}${speed} Mb/s${reset} ${dim}(${iface})${reset}"
      fi
    else
      echo "${yellow}Cannot read link speed.${reset}"
      echo "${dim}Try: iw dev ${iface} link${reset}"
    fi

    echo
    iw dev "$iface" link 2>/dev/null | while IFS= read -r line; do
      echo "  ${dim}${line}${reset}"
    done
  }

  # Live signal monitor
  monitor_signal() {
    local iface
    iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep ':wifi' | cut -d: -f1 | head -1)
    if [[ -z "$iface" ]]; then
      echo "${yellow}No Wi-Fi device found.${reset}"
      return
    fi

    local ssid
    ssid=$(iw dev "$iface" link 2>/dev/null | awk '/SSID:/{print $2}')
    if [[ -z "$ssid" ]]; then
      echo "${yellow}Not connected to any network.${reset}"
      return
    fi

    echo "${bold}Monitoring: ${cyan}${ssid}${reset} ${dim}(${iface})${reset}"
    echo "${dim}Press Ctrl-C to stop${reset}"
    echo

    trap 'echo; echo "${dim}Monitor stopped.${reset}"; return' INT

    while true; do
      local signal_dbm
      signal_dbm=$(iw dev "$iface" link 2>/dev/null | awk '/signal:/{print $2}')
      [[ -z "$signal_dbm" ]] && break

      local dbm_num=${signal_dbm//[^0-9-]/}
      # Match Waybar: clamp dBm to -90..-20, then convert to 30..100%.
      (( dbm_num > -20 )) && dbm_num=-20
      (( dbm_num < -90 )) && dbm_num=-90
      local pct=$(( dbm_num + 120 ))
      (( pct > 100 )) && pct=100
      (( pct < 0 )) && pct=0

      # Quality label
      local label color bar
      if   (( pct >= 80 )); then label="Excellent"; color="$green";     bar="▂▄▆█"
      elif (( pct >= 60 )); then label="Good";     color="$green";     bar="▂▄▆${dim}█${reset}"
      elif (( pct >= 40 )); then label="Fair";     color="$yellow";    bar="▂▄${dim}▆█${reset}"
      elif (( pct >= 20 )); then label="Weak";     color="$orange";    bar="▂${dim}▄▆█${reset}"
      else                       label="Bad";      color="$red";       bar="${dim}▂▄▆█${reset}"
      fi

      printf "\r  ${color}${bar}${reset} ${bold}%3d%%${reset} ${color}${signal_dbm}${reset}  ${color}${label}${reset}     "
      sleep 1
    done
  }

  # Main menu
  local -a menu=(
    "${green}󰤨${reset} ${purple}Scan Networks${reset}"
    "${cyan}󰤨${reset} ${purple}Show IP${reset}"
    "${yellow}󰤠${reset} ${purple}Bandwidth (interface)${reset}"
    "${yellow}󰄸${reset} ${purple}Bandwidth (processes)${reset}"
    "${cyan}󰦐${reset} ${purple}Listening Ports${reset}"
    "${yellow}󰚞${reset} ${purple}NetLog (nethogs)${reset}"
    "${blue}󰈀${reset} ${purple}Current Connection${reset}"
    "${blue}󰛳${reset} ${purple}Connection Speed${reset}"
    "${cyan}󰑌${reset} ${purple}Saved Connections${reset}"
    "${cyan}󰈈${reset} ${purple}Monitor Signal${reset}"
    "${orange}󰐧${reset} ${purple}Create Hotspot${reset}"
    "${red}󰖪${reset} ${purple}Disconnect${reset}"
    "${red}󰆴${reset} ${purple}Forget Network${reset}"
    "${yellow}󰤭${reset} ${purple}Toggle Wi-Fi${reset}"
    "${dim}󰅙${reset} ${dim}Quit${reset}"
  )

  while true; do
    local choice
    choice=$(printf "%s\n" "${menu[@]}" | command fzf \
      --ansi \
      --no-preview \
      --height=30% \
      --layout=reverse \
      --tiebreak=begin \
      --prompt "net > " \
      --border 2>/dev/null)

    [[ -z "$choice" ]] && break

    local plain
    plain=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

    case "$plain" in
      *Show\ IP*)    ip-show ;;
      *Bandwidth\ \(interface\)*) sudo bandwhich -i wlan0 ;;
      *Bandwidth\ \(processes\)*) sudo bandwhich --processes ;;
      *Listening\ Ports*) sudo lsof -i -P -n | grep LISTEN ;;
      *NetLog*)     sudo nethogs ;;
      *Scan*)       scan_networks ;;
      *Current*)    show_current ;;
      *Speed*)      show_speed ;;
      *Saved*)      list_saved ;;
      *Monitor*)    monitor_signal ;;
      *Hotspot*)    create_hotspot ;;
      *Disconnect*) disconnect_wifi ;;
      *Forget*)     forget_network ;;
      *Toggle*)     toggle_wifi ;;
      *Quit*)       break ;;
    esac
    echo
  done
}
