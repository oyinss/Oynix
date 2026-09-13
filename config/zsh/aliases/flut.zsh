#!/bin/zsh

flutter.() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  typeset -A commands=(
    ["󰄬 Doctor"]="flutter doctor"
    ["󰚰 Upgrade Project"]="flutter upgrade"
    ["󰚰 Update SDK (git pull)"]="update_sdk"
    ["󰇚 Get Packages"]="flutter pub get"
    ["󰆴 Clean"]="flutter clean"
    ["󰐕 Build APK"]="flutter build apk --release"
    ["󰐕 Build AppBundle"]="flutter build appbundle --release"
    ["󰖟 Build Web (auto renderer)"]="flutter build web --release"
    ["󰖟 Build Web (html)"]="flutter build web --release --web-renderer html"
    ["󰖟 Build Web (canvaskit)"]="flutter build web --release --web-renderer canvaskit"
    ["󰐊 Run on Device"]="flutter run"
    ["󰐊 Run Web"]="flutter run -d chrome"
    ["󰒓 Devices"]="flutter devices"
    ["󰄬 Analyze"]="flutter analyze"
    ["󰄬 Test"]="flutter test"
    ["󰐕 Create Project"]="create_project"
    ["󰅙 Quit"]="return"
  )

  local -a menu=(
    "${cyan}󰄬${reset} ${purple}Doctor${reset}"
    "${yellow}󰚰${reset} ${purple}Upgrade Project${reset}"
    "${yellow}󰚰${reset} ${purple}Update SDK (git pull)${reset}"
    "${green}󰇚${reset} ${purple}Get Packages${reset}"
    "${red}󰆴${reset} ${purple}Clean${reset}"
    "${green}󰐕${reset} ${purple}Build APK${reset}"
    "${green}󰐕${reset} ${purple}Build AppBundle${reset}"
    "${green}󰖟${reset} ${purple}Build Web (auto renderer)${reset}"
    "${green}󰖟${reset} ${purple}Build Web (html)${reset}"
    "${green}󰖟${reset} ${purple}Build Web (canvaskit)${reset}"
    "${green}󰐊${reset} ${purple}Run on Device${reset}"
    "${green}󰐊${reset} ${purple}Run Web${reset}"
    "${cyan}󰒓${reset} ${purple}Devices${reset}"
    "${cyan}󰄬${reset} ${purple}Analyze${reset}"
    "${cyan}󰄬${reset} ${purple}Test${reset}"
    "${green}󰐕${reset} ${purple}Create Project${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height=20 --border --prompt "Flutter › ")
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  if [[ -n $plain_choice ]]; then
    eval "${commands[$plain_choice]}"
  fi
}

update_sdk() {
  (cd ~/flutter && git pull && flutter upgrade)
}

create_project() {
  echo -n "Enter project name: "
  read pname
  if [[ -n "$pname" ]]; then
    flutter create "$pname" && echo "✅ Project created: $pname"
  else
    echo "❌ No name entered."
  fi
}
