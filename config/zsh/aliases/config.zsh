#!/bin/zsh

conf() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local orange=$'\033[38;5;208m'

  # Config files: terminals/multiplexer, editors, window manager, shell, git, system
  declare -A configs=(
    ["󰾫 Edit Ghostty Config"]="nvim ~/.config/ghostty/config"
    ["󰾫 Edit Kitty Config"]="nvim ~/.config/kitty/kitty.conf"
    ["󰾫 Edit tmux Config"]="nvim ~/.config/tmux/tmux.conf"
    ["󰾫 Edit Neovim Config"]="nvim ~/.config/nvim/init.lua"
    ["󰾫 Edit Yazi Config"]="nvim ~/.config/yazi/yazi.toml"
    ["󰾫 Edit Walker Config"]="nvim ~/.config/walker/config.toml"
    ["󰾫 Edit Cava Config"]="nvim ~/.config/cava/config1"
    ["󰾫 Edit btop Config"]="nvim ~/.config/btop/btop.conf"
    ["󰾫 Edit Hyprland Config"]="nvim ~/.config/hypr/hyprland.lua"
    ["󰾫 Edit Hyprland Keybinds"]="nvim ~/.config/hypr/custom/keybinds.lua"
    ["󰾫 Edit Zsh Config"]="nvim ~/.config/zsh/core.zsh"
    ["󰾫 Edit Fish Config"]="nvim ~/.config/fish/config.fish"
    ["󰾫 Edit Starship Prompt"]="nvim ~/.config/starship.toml"
    ["󰾫 Edit Text Expander"]="nvim ~/.config/text_expander/base.yml"
    ["󰾫 Edit Git Config"]="nvim ~/.gitconfig"
    ["󰾫 Edit Git Ignore (global)"]="nvim ~/.config/git/ignore"
    ["󰾫 Edit Auto-CPUFreq Config"]="nvim ~/Oynix/etc/auto-cpufreq.conf"
    ["󰾫 Edit GRUB Config"]="sudo nvim /etc/default/grub"
    ["󰾫 Edit mkinitcpio Config"]="sudo nvim /etc/mkinitcpio.conf"
    ["󰾫 Edit Pacman Config"]="sudo nvim /etc/pacman.conf"
    ["󰾫 Edit Environment Variables"]="sudo nvim /etc/environment"
    ["󰾫 Edit Hosts File"]="sudo nvim /etc/hosts"
    ["󰾫 Edit AdGuard DNS Config"]="sudo nvim /etc/systemd/resolved.conf"
    ["󰾫 Edit FSTAB"]="sudo nvim /etc/fstab"
    ["󰗙 Quit"]=": # Do nothing"
  )

  local -a menu=(
    "${blue}󰾫${reset} ${purple}Edit Ghostty Config${reset}"
    "${blue}󰾫${reset} ${purple}Edit Kitty Config${reset}"
    "${blue}󰾫${reset} ${purple}Edit tmux Config${reset}"
    "${cyan}󰾫${reset} ${purple}Edit Neovim Config${reset}"
    "${cyan}󰾫${reset} ${purple}Edit Yazi Config${reset}"
    "${cyan}󰾫${reset} ${purple}Edit Walker Config${reset}"
    "${cyan}󰾫${reset} ${purple}Edit Cava Config${reset}"
    "${cyan}󰾫${reset} ${purple}Edit btop Config${reset}"
    "${green}󰾫${reset} ${purple}Edit Hyprland Config${reset}"
    "${green}󰾫${reset} ${purple}Edit Hyprland Keybinds${reset}"
    "${green}󰾫${reset} ${purple}Edit Zsh Config${reset}"
    "${green}󰾫${reset} ${purple}Edit Fish Config${reset}"
    "${green}󰾫${reset} ${purple}Edit Starship Prompt${reset}"
    "${green}󰾫${reset} ${purple}Edit Text Expander${reset}"
    "${purple}󰾫${reset} ${purple}Edit Git Config${reset}"
    "${purple}󰾫${reset} ${purple}Edit Git Ignore (global)${reset}"
    "${yellow}󰾫${reset} ${purple}Edit Auto-CPUFreq Config${reset}"
    "${yellow}󰾫${reset} ${purple}Edit GRUB Config${reset}"
    "${yellow}󰾫${reset} ${purple}Edit mkinitcpio Config${reset}"
    "${yellow}󰾫${reset} ${purple}Edit Pacman Config${reset}"
    "${yellow}󰾫${reset} ${purple}Edit Environment Variables${reset}"
    "${yellow}󰾫${reset} ${purple}Edit Hosts File${reset}"
    "${yellow}󰾫${reset} ${purple}Edit AdGuard DNS Config${reset}"
    "${yellow}󰾫${reset} ${purple}Edit FSTAB${reset}"
    "${orange}󰗙${reset} ${purple}Quit${reset}"
  )

  # fzf selection menu (Esc cancels silently)
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 22 --prompt "Config Files › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the selected command
  if [[ -n $plain_choice ]]; then
    eval "${configs[$plain_choice]}"
  fi
}
