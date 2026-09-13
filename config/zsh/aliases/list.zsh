#!/bin/zsh

l() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with list commands
  declare -A commands=(
    ["󰉋 All Files (with icons)"]="eza -a --icons=auto --sort=name --group-directories-first -1"
    ["󰈙 Row View"]="eza -h --icons=auto"
    ["󰈙 All Row View"]="eza -a --icons=auto --sort=name --group-directories-first"
    ["󰏗 One Line"]="eza -1 --icons=auto"
    ["󰒓 Details"]="eza -lh --icons=auto"
    ["󰒓 All Details"]="eza -lha --icons=auto --sort=name --group-directories-first"
    ["󰉋 Directories Only"]="eza -lhD --icons=auto"
  )

  local -a menu=(
    "${cyan}󰉋${reset} ${purple}All Files (with icons)${reset}"
    "${cyan}󰈙${reset} ${purple}Row View${reset}"
    "${cyan}󰈙${reset} ${purple}All Row View${reset}"
    "${blue}󰏗${reset} ${purple}One Line${reset}"
    "${blue}󰒓${reset} ${purple}Details${reset}"
    "${blue}󰒓${reset} ${purple}All Details${reset}"
    "${yellow}󰉋${reset} ${purple}Directories Only${reset}"
  )

  # fzf menu selection
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 10 --prompt "View Mode › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute selected command
  if [[ -n "$plain_choice" ]]; then
    eval "${commands[$plain_choice]}"
  fi
}
