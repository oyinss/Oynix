#!/bin/zsh

flatpak.() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define the fpurge function for uninstalling apps
  fpurge() {
    # List installed Flatpak apps and select one using fzf
    local app=$(flatpak list --app --columns=application | fzf --no-preview --prompt="Select Flatpak app to uninstall: ")

    # Uninstall the selected app if any
    if [[ -n "$app" ]]; then
      flatpak uninstall -y "$app"
      echo "$app has been uninstalled."
    else
      echo "No app selected. Exiting."
    fi
  }

  # Define an associative array with Flatpak commands as keys and corresponding commands as values
  declare -A commands=(
    ["󰒓 List Installed Flatpak Apps"]="flatpak list"
    ["󰇚 Install a Flatpak App"]="flatpak install"
    ["󰆴 Uninstall a Flatpak App"]="fpurge"  # Calls your fpurge function
    ["󰚰 Update all Flatpak Apps"]="flatpak update"
    ["󰍉 Search for Flatpak Apps"]="flatpak search"
    ["󰋼 Show Info About a Flatpak App"]="flatpak info"
    ["󰐕 Add a Remote Flatpak Repo"]="flatpak remote-add"
    ["󰗼 Remove a Remote Flatpak Repo"]="flatpak remote-delete"
    ["󰐊 Run a Flatpak App"]="flatpak run"
    ["󰅙 Quit"]=": # Do nothing"
  )

  local -a menu=(
    "${cyan}󰒓${reset} ${purple}List Installed Flatpak Apps${reset}"
    "${green}󰇚${reset} ${purple}Install a Flatpak App${reset}"
    "${red}󰆴${reset} ${purple}Uninstall a Flatpak App${reset}"
    "${yellow}󰚰${reset} ${purple}Update all Flatpak Apps${reset}"
    "${blue}󰍉${reset} ${purple}Search for Flatpak Apps${reset}"
    "${cyan}󰋼${reset} ${purple}Show Info About a Flatpak App${reset}"
    "${green}󰐕${reset} ${purple}Add a Remote Flatpak Repo${reset}"
    "${red}󰗼${reset} ${purple}Remove a Remote Flatpak Repo${reset}"
    "${green}󰐊${reset} ${purple}Run a Flatpak App${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  # Use fzf to display the Flatpak commands and store the selection
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 10 --prompt "Select a Flatpak command: " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the corresponding command based on the selection
  if [[ -n $plain_choice ]]; then
    if [[ "$plain_choice" == "Uninstall a Flatpak App" ]]; then
      fpurge  # Call fpurge for uninstall
    else
      eval "${commands[$plain_choice]}"
    fi
  fi
}
