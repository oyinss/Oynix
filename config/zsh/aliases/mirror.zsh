#!/bin/zsh

# █   █ ███ ███ ███ ███ ███   ███ █   ███ ███ ███ ███ ███
# ██ ██  █  █ █ █ █ █ █ █ █   █ █ █    █  █ █ █   █   █
# █ █ █  █  ██  ██  █ █ ██    █ █ █    █  █ █  █  ███  █
# █   █  █  █ █ █ █ █ █ █ █   ███ █    █  ███   █ █     █
# █   █ ███ █ █ █ █ ███ █ █   █ █ ███ ███ █ █ ███ ███ ███

mirror() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with mirror commands
  declare -A commands=(
    ["󰖟 Reflector Update Fastest Mirror Worldwide"]="sudo reflector --protocol https --sort rate --save /etc/pacman.d/mirrorlist"
    ["󰖟 Reflector Update 30 Fastest Mirror Worldwide"]="sudo reflector --protocol https --sort rate --number 30 --save /etc/pacman.d/mirrorlist"
    ["󰚰 Rate Update Manjaro Mirrors"]="rate-mirrors --allow-root --protocol https manjaro | sudo tee /etc/pacman.d/mirrorlist"
    ["󰚰 Rate Update EndeavourOS Mirrors"]="rate-mirrors --allow-root --protocol https endeavouros | sudo tee /etc/pacman.d/endeavouros-mirrorlist"
    ["󰒓 Rank Current Mirrors"]="rankmirrors /etc/pacman.d/mirrorlist"
    ["󰈙 EndeavourOS Mirror List"]="sudo nvim /etc/pacman.d/endeavouros-mirrorlist"
    ["󰈙 Arch Mirror List"]="sudo nvim /etc/pacman.d/mirrorlist"
    ["󰈙 Chaotic Mirror List"]="sudo nvim /etc/pacman.d/chaotic-mirrorlist"
    ["󰏫 Configure pacman.conf"]="sudo nvim /etc/pacman.conf"
    ["󰅙 Quit"]=": # Do nothing"
  )

  local -a menu=(
    "${blue}󰖟${reset} ${purple}Reflector Update Fastest Mirror Worldwide${reset}"
    "${blue}󰖟${reset} ${purple}Reflector Update 30 Fastest Mirror Worldwide${reset}"
    "${green}󰚰${reset} ${purple}Rate Update Manjaro Mirrors${reset}"
    "${green}󰚰${reset} ${purple}Rate Update EndeavourOS Mirrors${reset}"
    "${cyan}󰒓${reset} ${purple}Rank Current Mirrors${reset}"
    "${yellow}󰈙${reset} ${purple}EndeavourOS Mirror List${reset}"
    "${yellow}󰈙${reset} ${purple}Arch Mirror List${reset}"
    "${yellow}󰈙${reset} ${purple}Chaotic Mirror List${reset}"
    "${yellow}󰏫${reset} ${purple}Configure pacman.conf${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  # fzf menu selection
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 15 --prompt "Mirrors › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the selected command
  if [[ -n $plain_choice ]]; then
    eval "${commands[$plain_choice]}"
  fi
}
