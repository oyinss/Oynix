#!/bin/zsh

kwin.() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  typeset -A actions=(
    ["󰒓 Set Meta to KRunner"]="kwriteconfig5 --file ~/.config/kwinrc --group ModifierOnlyShortcuts --key Meta \"org.kde.krunner,/App,,toggleDisplay\" && qdbus org.kde.KWin /KWin reconfigure"
    ["󰒓 Set Meta to Application Launcher"]="kwriteconfig5 --file ~/.config/kwinrc --group ModifierOnlyShortcuts --key Meta \"org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu\" && qdbus org.kde.KWin /KWin reconfigure"
    ["󰒓 Set Meta to ExposeAll"]="kwriteconfig5 --file ~/.config/kwinrc --group ModifierOnlyShortcuts --key Meta \"org.kde.kglobalaccel,/component/kwin,org.kde.kglobalaccel.Component,invokeShortcut,ExposeAll\" && qdbus org.kde.KWin /KWin reconfigure"
    ["󰒓 Set Meta to Overview"]="kwriteconfig5 --file ~/.config/kwinrc --group ModifierOnlyShortcuts --key Meta \"org.kde.kglobalaccel,/component/kwin,org.kde.kglobalaccel.Component,invokeShortcut,Overview\" && qdbus org.kde.KWin /KWin reconfigure"
    ["󰅖 Disable Meta Key"]="kwriteconfig5 --file ~/.config/kwinrc --group ModifierOnlyShortcuts --key Meta \"\" && qdbus org.kde.KWin /KWin reconfigure"
    ["󰍉 List Meta Bindings"]="qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.shortcutNames"
    ["󰑓 Reload KWin"]="qdbus org.kde.KWin /KWin reconfigure"
    ["󰅙 Quit"]="return"
  )

  local -a menu=(
    "${yellow}󰒓${reset} ${purple}Set Meta to KRunner${reset}"
    "${yellow}󰒓${reset} ${purple}Set Meta to Application Launcher${reset}"
    "${yellow}󰒓${reset} ${purple}Set Meta to ExposeAll${reset}"
    "${yellow}󰒓${reset} ${purple}Set Meta to Overview${reset}"
    "${red}󰅖${reset} ${purple}Disable Meta Key${reset}"
    "${cyan}󰍉${reset} ${purple}List Meta Bindings${reset}"
    "${yellow}󰑓${reset} ${purple}Reload KWin${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height=14 --prompt="KWin Meta Key › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  if [[ -n $plain_choice ]]; then
    eval "${actions[$plain_choice]}"
  fi
}
