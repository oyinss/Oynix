# ~/.zsh/aliases/asdfpy.zsh

asdf.() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  typeset -A actions=(
    ["󰌾 Set Global Python Version"]="asdfpy_set_global"
    ["󰇚 Install New Python Version"]="asdfpy_install"
    ["󰆴 Uninstall Python Version"]="asdfpy_uninstall"
    ["󰒓 Show Installed Versions"]="asdf list python | bat --plain"
    ["󰋼 Show Active Python Info"]="echo \"Version: \$(python --version)\nPath: \$(which python)\" | bat --plain"
    ["󰑕 Revert to System Python"]="asdf global python system && echo '✔️  Reverted to system Python'"
    ["󰅙 Quit"]="return"
  )

  local -a menu=(
    "${yellow}󰌾${reset} ${purple}Set Global Python Version${reset}"
    "${green}󰇚${reset} ${purple}Install New Python Version${reset}"
    "${red}󰆴${reset} ${purple}Uninstall Python Version${reset}"
    "${cyan}󰒓${reset} ${purple}Show Installed Versions${reset}"
    "${cyan}󰋼${reset} ${purple}Show Active Python Info${reset}"
    "${yellow}󰑕${reset} ${purple}Revert to System Python${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --prompt="ASDF Python › " --height=40% --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  if [[ -n $plain_choice ]]; then
    eval "${actions[$plain_choice]}"
  fi
}

asdfpy_set_global() {
  local version=$(asdf list python | fzf --no-preview --prompt="Select version to activate: " --height=40%)
  [[ -n $version ]] && asdf global python "$version" && echo "✔️  Set Python $version globally"
}

asdfpy_install() {
  local version
  read "version?Enter Python version to install: "
  [[ -n $version ]] && asdf install python "$version" && echo "✔️  Installed Python $version"
}

asdfpy_uninstall() {
  local version=$(asdf list python | fzf --no-preview --prompt="Select version to uninstall: " --height=40%)
  [[ -n $version ]] && asdf uninstall python "$version" && echo "🧹 Uninstalled Python $version"
}
