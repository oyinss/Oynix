#!/bin/zsh

nvidia() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with command names as keys and corresponding commands as values
  declare -A commands=(
    ["󰍉 Check which GPU is currently in use (Nvidia or Intel)"]='lspci -k | grep -A 2 -E "(VGA|3D)"'
    ["󰆴 Unload Nvidia modules (nvidia_modeset, nvidia_uvm, nvidia_drm, nvidia)"]="sudo rmmod nvidia_modeset nvidia_uvm nvidia_drm nvidia"
    ["󰇚 Load Nvidia modules (nvidia, nvidia_modeset, nvidia_uvm, nvidia_drm)"]="sudo modprobe nvidia nvidia_modeset nvidia_uvm nvidia_drm"
    ["󰑓 Switch to Intel GPU"]="sudo prime-select intel"
    ["󰑓 Switch to Nvidia GPU"]="sudo prime-select nvidia"
    ["󰓛 Turn off Nvidia GPU (bbswitch)"]="echo OFF | sudo tee /proc/acpi/bbswitch"
    ["󰐊 Turn on Nvidia GPU (bbswitch)"]="echo ON | sudo tee /proc/acpi/bbswitch"
    ["󰒓 Open Nvidia Settings"]="nvidia-settings"
    ["󰐊 Run Nvidia SMI"]="nvidia-smi"
    ["󰚰 Generate Mkinitcpio"]="sudo mkinitcpio -P"
    ["󰇚 Install Nvidia LTS/ZEN Kernel && Generate mkinitcpio"]="sudo pacman -S nvidia-dkms nvidia-utils nvidia-settings cuda && sudo mkinitcpio -P"
    ["󰇚 Install Nvidia Open drivers && Generate mkinitcpio"]="sudo pacman -S nvidia-open nvidia-utils nvidia-settings cuda && sudo mkinitcpio -P"
    ["󰅙 Quit"]=": # Do nothing"
  )

  local -a menu=(
    "${cyan}󰍉${reset} ${purple}Check which GPU is currently in use (Nvidia or Intel)${reset}"
    "${red}󰆴${reset} ${purple}Unload Nvidia modules (nvidia_modeset, nvidia_uvm, nvidia_drm, nvidia)${reset}"
    "${green}󰇚${reset} ${purple}Load Nvidia modules (nvidia, nvidia_modeset, nvidia_uvm, nvidia_drm)${reset}"
    "${yellow}󰑓${reset} ${purple}Switch to Intel GPU${reset}"
    "${yellow}󰑓${reset} ${purple}Switch to Nvidia GPU${reset}"
    "${red}󰓛${reset} ${purple}Turn off Nvidia GPU (bbswitch)${reset}"
    "${green}󰐊${reset} ${purple}Turn on Nvidia GPU (bbswitch)${reset}"
    "${cyan}󰒓${reset} ${purple}Open Nvidia Settings${reset}"
    "${blue}󰐊${reset} ${purple}Run Nvidia SMI${reset}"
    "${orange}󰚰${reset} ${purple}Generate Mkinitcpio${reset}"
    "${green}󰇚${reset} ${purple}Install Nvidia LTS/ZEN Kernel && Generate mkinitcpio${reset}"
    "${green}󰇚${reset} ${purple}Install Nvidia Open drivers && Generate mkinitcpio${reset}"
    "${red}󰅙${reset} ${purple}Quit${reset}"
  )

  # Use fzf to display the options and store the selection
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 10 --prompt "Select a Nvidia command: " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the corresponding command based on the selection
  if [[ -n $plain_choice ]]; then
    eval "${commands[$plain_choice]}"
  fi
}
