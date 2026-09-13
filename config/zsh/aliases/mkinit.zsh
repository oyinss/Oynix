#!/bin/zsh

mkinit() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with mkinitcpio commands
  declare -A commands=(
    ["󰚰 Update/Generate initramfs"]="sudo mkinitcpio -P"
    ["󰏫 Edit mkinitcpio Config"]="sudo nvim /etc/mkinitcpio.conf"
    ["󰏗 List Available Hooks"]="ls /usr/lib/initcpio/hooks"
    ["󰉋 List Installed Presets"]="ls /etc/mkinitcpio.d/"
    ["󰅙 Quit"]=": # Do nothing"
  )

  local -a menu=(
    "${yellow}󰚰${reset} ${purple}Update/Generate initramfs${reset}"
    "${yellow}󰏫${reset} ${purple}Edit mkinitcpio Config${reset}"
    "${cyan}󰏗${reset} ${purple}List Available Hooks${reset}"
    "${cyan}󰉋${reset} ${purple}List Installed Presets${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  # Use fzf to display the options and store the selection
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 10 --prompt "mkinitcpio › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the selected command
  if [[ -n $plain_choice ]]; then
    eval "${commands[$plain_choice]}"
  fi
}
