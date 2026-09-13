#!/bin/zsh

grub() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with glyph-labeled keys
  declare -A commands=(
    ["󰑓 Update GRUB"]="sudo grub-mkconfig -o /boot/grub/grub.cfg"
    ["󰏫 Grub Configuration"]="sudo nvim /etc/default/grub"
    ["󰅙 Quit"]=": # Do nothing"
  )

  local -a menu=(
    "${yellow}󰑓${reset} ${purple}Update GRUB${reset}"
    "${yellow}󰏫${reset} ${purple}Grub Configuration${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  # Use fzf to display the glyph-labeled options
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 10 --border --prompt "GRUB › ")
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the selected command
  if [[ -n $plain_choice ]]; then
    eval "${commands[$plain_choice]}"
  fi
}
