#!/bin/zsh

dns() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with NextDNS commands
  declare -A commands=(
    ["󰇚 Install/Upgrade/Uninstall NextDNS"]="sh -c '$(curl -sL https://nextdns.io/install)'"
    ["󰐊 Start NextDNS"]="nextdns start"
    ["󰓛 Stop NextDNS"]="nextdns stop"
    ["󰑓 Restart NextDNS"]="nextdns restart"
    ["󰌾 Activate NextDNS"]="sudo nextdns activate"
    ["󰌾 Deactivate NextDNS"]="sudo nextdns deactivate"
    ["󰒓 Show NextDNS Logs"]="nextdns log"
    ["󰋼 Help and More Commands"]="nextdns help"
    ["󰅙 Quit"]=": # Quit the function"
  )

  local -a menu=(
    "${blue}󰇚${reset} ${purple}Install/Upgrade/Uninstall NextDNS${reset}"
    "${green}󰐊${reset} ${purple}Start NextDNS${reset}"
    "${red}󰓛${reset} ${purple}Stop NextDNS${reset}"
    "${yellow}󰑓${reset} ${purple}Restart NextDNS${reset}"
    "${green}󰌾${reset} ${purple}Activate NextDNS${reset}"
    "${red}󰌾${reset} ${purple}Deactivate NextDNS${reset}"
    "${cyan}󰒓${reset} ${purple}Show NextDNS Logs${reset}"
    "${orange}󰋼${reset} ${purple}Help and More Commands${reset}"
    "${red}󰅙${reset} ${purple}Quit${reset}"
  )

  while true; do
    # Use fzf to display the commands and store the selection
    local choice plain_choice
    choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 10 --prompt "Select a NextDNS command (or Quit): " --border)
    plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

    # If no command is selected or 'Quit' is chosen, exit the loop
    if [[ -z "$plain_choice" || "$plain_choice" == "Quit" ]]; then
      echo "Exiting NextDNS manager."
      break
    fi

    # Execute the selected command
    eval "${commands[$plain_choice]}"
  done
}
