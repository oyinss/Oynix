#!/bin/zsh

# Function to update a specific section of auto-cpufreq.conf
change_cpu_mode() {
  local mode=$1
  local section=$2
  local conf="/etc/auto-cpufreq.conf"

  local preference
  case $mode in
    performance) preference="performance" ;;
    schedutil|ondemand) preference="balance_performance" ;;
    conservative|powersave) preference="power" ;;
    *) preference="default" ;;
  esac

  sudo sed -i "/^\[$section\]/,/^\[.*\]/ {
    s/^governor = .*/governor = $mode/
    s/^energy_performance_preference = .*/energy_performance_preference = $preference/
    s/^turbo = .*/turbo = never/
  }" $conf

  echo "✅ [$section] governor set to $mode (energy_pref: $preference)"
}

cpu() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  local -a menu=(
    # View/edit system info
    "${cyan}󰍹${reset} ${purple}View CPU Stats${reset}"
    "${cyan}󰍉${reset} ${purple}Check CPU Governor${reset}"
    "${yellow}󰏫${reset} ${purple}Edit Auto-CPUFreq Config (System)${reset}"

    # Auto-CPUFreq service control
    "${green}󰐊${reset} ${purple}Start Auto-CPUFreq${reset}"
    "${red}󰓛${reset} ${purple}Stop Auto-CPUFreq${reset}"

    # Governor: Charger
    "${yellow}󰚥${reset} ${purple}performance${reset}"
    "${yellow}󰚥${reset} ${purple}schedutil${reset}"
    "${yellow}󰚥${reset} ${purple}userspace${reset}"
    "${yellow}󰚥${reset} ${purple}ondemand${reset}"
    "${yellow}󰚥${reset} ${purple}conservative${reset}"
    "${yellow}󰚥${reset} ${purple}powersave${reset}"

    # Governor: Battery
    "${blue}󰁹${reset} ${purple}performance${reset}"
    "${blue}󰁹${reset} ${purple}schedutil${reset}"
    "${blue}󰁹${reset} ${purple}userspace${reset}"
    "${blue}󰁹${reset} ${purple}ondemand${reset}"
    "${blue}󰁹${reset} ${purple}conservative${reset}"
    "${blue}󰁹${reset} ${purple}powersave${reset}"

    # Exit
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 22 --prompt "CPU Options › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  case "$plain_choice" in
    "󰍹 View CPU Stats") sudo auto-cpufreq --stats ;;
    "󰍉 Check CPU Governor") cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor ;;
    "󰏫 Edit Auto-CPUFreq Config (System)") sudo nvim /etc/auto-cpufreq.conf ;;

    "󰐊 Start Auto-CPUFreq") sudo auto-cpufreq --install ;;
    "󰓛 Stop Auto-CPUFreq") sudo auto-cpufreq --remove ;;

    "󰚥 performance") change_cpu_mode performance charger ;;
    "󰚥 schedutil") change_cpu_mode schedutil charger ;;
    "󰚥 userspace") change_cpu_mode userspace charger ;;
    "󰚥 ondemand") change_cpu_mode ondemand charger ;;
    "󰚥 conservative") change_cpu_mode conservative charger ;;
    "󰚥 powersave") change_cpu_mode powersave charger ;;

    "󰁹 performance") change_cpu_mode performance battery ;;
    "󰁹 schedutil") change_cpu_mode schedutil battery ;;
    "󰁹 userspace") change_cpu_mode userspace battery ;;
    "󰁹 ondemand") change_cpu_mode ondemand battery ;;
    "󰁹 conservative") change_cpu_mode conservative battery ;;
    "󰁹 powersave") change_cpu_mode powersave battery ;;

    "󰅙 Quit") return ;;
    *) return ;;
  esac
}
