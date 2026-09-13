#!/bin/zsh

docker.() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  typeset -A commands=(
    ["󰍉 Running Containers"]="docker PS"
    ["󰒓 All Containers"]="docker ps -a"
    ["󰒓 Show Containers"]="docker ps -a"
    ["󰒓 Compose PS"]="docker compose ps"
    ["󰏗 Show Images"]="docker images"
    ["󰆴 System Prune"]="docker system prune -af"
    ["󰆴 Remove All Containers & Images"]="docker rm -f \$(docker ps -aq) && docker rmi -f \$(docker images -q)"
    ["󰆴 Remove Container"]="remove_container"
    ["󰐊 Start Container"]="start_container"
    ["󰓛 Stop Container"]="stop_container"
    ["󰓛 Stop All Containers"]="docker stop \$(docker ps -q)"
    ["󰑓 Restart Container"]="restart_container"
    ["󰒓 Logs (Follow)"]="logs_container"
    ["󰆍 Exec Shell (sh)"]="sh_container"
    ["󰆍 Exec Shell (bash)"]="bash_container"
    ["󰐊 Run Container"]="run_container"
    ["󰏗 Compose Build"]="docker-compose build"
    ["󰐊 Compose Up"]="docker-compose up -d"
    ["󰓛 Compose Down"]="docker-compose down"
    ["󰑓 Compose Restart"]="docker-compose down && docker-compose up -d"
    ["󰆍 Compose Exec"]="compose_exec"
    ["󰅙 Quit"]="return"
  )

  local -a menu=(
    "${cyan}󰍉${reset} ${purple}Running Containers${reset}"
    "${cyan}󰒓${reset} ${purple}All Containers${reset}"
    "${cyan}󰒓${reset} ${purple}Show Containers${reset}"
    "${cyan}󰒓${reset} ${purple}Compose PS${reset}"
    "${blue}󰏗${reset} ${purple}Show Images${reset}"
    "${red}󰆴${reset} ${purple}System Prune${reset}"
    "${red}󰆴${reset} ${purple}Remove All Containers & Images${reset}"
    "${red}󰆴${reset} ${purple}Remove Container${reset}"
    "${green}󰐊${reset} ${purple}Start Container${reset}"
    "${red}󰓛${reset} ${purple}Stop Container${reset}"
    "${red}󰓛${reset} ${purple}Stop All Containers${reset}"
    "${yellow}󰑓${reset} ${purple}Restart Container${reset}"
    "${cyan}󰒓${reset} ${purple}Logs (Follow)${reset}"
    "${blue}󰆍${reset} ${purple}Exec Shell (sh)${reset}"
    "${blue}󰆍${reset} ${purple}Exec Shell (bash)${reset}"
    "${green}󰐊${reset} ${purple}Run Container${reset}"
    "${yellow}󰏗${reset} ${purple}Compose Build${reset}"
    "${green}󰐊${reset} ${purple}Compose Up${reset}"
    "${red}󰓛${reset} ${purple}Compose Down${reset}"
    "${yellow}󰑓${reset} ${purple}Compose Restart${reset}"
    "${blue}󰆍${reset} ${purple}Compose Exec${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height=20 --prompt="Docker › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  if [[ -n $plain_choice ]]; then
    eval "${commands[$plain_choice]}"
  fi
}

start_container() {
  local id=$(docker ps -a --format '{{.Names}}' | fzf --no-preview --prompt="Start container › ")
  [[ -n "$id" ]] && docker start "$id" && echo "✅ Started: $id"
}

stop_container() {
  local id=$(docker ps --format '{{.Names}}' | fzf --no-preview --prompt="Stop container › ")
  [[ -n "$id" ]] && docker stop "$id" && echo "⏹️ Stopped: $id"
}

restart_container() {
  local id=$(docker ps --format '{{.Names}}' | fzf --no-preview --prompt="Restart container › ")
  [[ -n "$id" ]] && docker restart "$id" && echo "🔄 Restarted: $id"
}

remove_container() {
  local id=$(docker ps -a --format '{{.Names}}' | fzf --no-preview --prompt="Remove container › ")
  [[ -n "$id" ]] && docker rm -f "$id" && echo "✅ Removed: $id"
}

logs_container() {
  local id=$(docker ps --format '{{.Names}}' | fzf --no-preview --prompt="Follow logs › ")
  [[ -n "$id" ]] && docker logs -f "$id"
}

sh_container() {
  local id=$(docker ps --format '{{.Names}}' | fzf --no-preview --prompt="Open sh › ")
  [[ -n "$id" ]] && docker exec -it "$id" sh
}

bash_container() {
  local id=$(docker ps --format '{{.Names}}' | fzf --no-preview --prompt="Open bash › ")
  [[ -n "$id" ]] && docker exec -it "$id" bash
}

run_container() {
  echo "⚠️  Example: ubuntu bash"
  echo -n "Enter image + args: "
  read cmd
  [[ -n "$cmd" ]] && docker run --rm -it $cmd
}

compose_exec() {
  echo -n "Service name: "
  read svc
  echo -n "Command (e.g., sh): "
  read cmd
  [[ -n "$svc" && -n "$cmd" ]] && docker-compose exec "$svc" "$cmd"
}
