#!/bin/zsh

kernel() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with kernel commands
  declare -A commands=(
    ["󰍉 Check current kernel version"]="uname -r"
    ["󰋼 Check detailed kernel version"]="uname -a"
    ["󰒓 List all installed kernels"]="pacman -Q | grep linux"
    ["󰆴 Remove old kernels"]="sudo pacman -Rns $(pacman -Qdtq)"
    ["󰚰 Update initramfs"]="sudo mkinitcpio -P"
    ["󰚰 Update GRUB"]="sudo grub-mkconfig -o /boot/grub/grub.cfg"
    ["󰑓 Update grub and initramfs"]="sudo grub-mkconfig -o /boot/grub/grub.cfg && sudo mkinitcpio -P"
    ["󰇚 Install latest kernel"]="sudo pacman -Syu linux"
    ["󰇚 Install Zen kernel"]="sudo pacman -S linux-zen linux-zen-headers"
    ["󰇚 Install LTS kernel"]="sudo pacman -S linux-lts linux-lts-headers"
    ["󰈙 Check kernel logs (dmesg)"]="dmesg | less"
    ["󰅙 Quit"]=": # Do nothing"
  )

  local -a menu=(
    "${cyan}󰍉${reset} ${purple}Check current kernel version${reset}"
    "${cyan}󰋼${reset} ${purple}Check detailed kernel version${reset}"
    "${cyan}󰒓${reset} ${purple}List all installed kernels${reset}"
    "${red}󰆴${reset} ${purple}Remove old kernels${reset}"
    "${yellow}󰚰${reset} ${purple}Update initramfs${reset}"
    "${yellow}󰚰${reset} ${purple}Update GRUB${reset}"
    "${yellow}󰑓${reset} ${purple}Update grub and initramfs${reset}"
    "${green}󰇚${reset} ${purple}Install latest kernel${reset}"
    "${green}󰇚${reset} ${purple}Install Zen kernel${reset}"
    "${green}󰇚${reset} ${purple}Install LTS kernel${reset}"
    "${cyan}󰈙${reset} ${purple}Check kernel logs (dmesg)${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  # fzf selection menu
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 15 --prompt "Kernel › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the selected command
  if [[ -n $plain_choice ]]; then
    eval "${commands[$plain_choice]}"
  fi
}
