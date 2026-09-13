#!/bin/zsh

dir() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with directory cd commands
  declare -A directories=(
    ["󰉋 Config"]="cd ~/.config"
    ["󰏫 Neovim Config"]="cd ~/.config/nvim"
    ["󰉋 Dotfiles"]="cd ~/Oynix"
    ["󰉋 Hub"]="cd ~/Hub"
    ["󰏫 Kitty Config"]="cd ~/.config/kitty/"
    ["󰏗 Pacman Cache (PKG)"]="cd /var/cache/pacman/pkg"
    ["󰏫 Alacritty Config"]="cd ~/.config/alacritty/"
    ["󰋩 Pictures"]="cd ~/Pictures"
    ["󰈙 Aliases"]="cd ~/Oynix/config/zsh/aliases"
    ["󰆍 Zsh"]="cd ~/Oynix/config/zsh"
  )

  local -a menu=(
    "${cyan}󰉋${reset} ${purple}Config${reset}"
    "${cyan}󰏫${reset} ${purple}Neovim Config${reset}"
    "${cyan}󰉋${reset} ${purple}Dotfiles${reset}"
    "${cyan}󰉋${reset} ${purple}Hub${reset}"
    "${cyan}󰏫${reset} ${purple}Kitty Config${reset}"
    "${cyan}󰏗${reset} ${purple}Pacman Cache (PKG)${reset}"
    "${cyan}󰏫${reset} ${purple}Alacritty Config${reset}"
    "${cyan}󰋩${reset} ${purple}Pictures${reset}"
    "${cyan}󰈙${reset} ${purple}Aliases${reset}"
    "${cyan}󰆍${reset} ${purple}Zsh${reset}"
  )

  # Use fzf to display the directory options
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 15 --prompt "Directories › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the selected cd command
  if [[ -n $plain_choice ]]; then
    eval "${directories[$plain_choice]}"
  fi
}
