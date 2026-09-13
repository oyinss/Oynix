#!/bin/zsh

jctl() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  local service=$(systemctl list-units --type=service --all --no-pager --no-legend \
    | awk '{print $1}' | fzf --no-preview --prompt="Select service for logs: " --height=15)

  if [[ -z "$service" ]]; then
    return 1
  fi

  echo "🟢 Selected service: $service"

  local -a menu=(
    "${cyan}󰒓${reset} ${purple}Show recent logs (last 50 lines)${reset}"
    "${green}󰐊${reset} ${purple}Follow logs (live)${reset}"
    "${cyan}󰒓${reset} ${purple}Show logs since today${reset}"
    "${cyan}󰒓${reset} ${purple}Show full logs${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  local action plain_action
  action=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --prompt="Journalctl › " --height=7)
  plain_action=$(print -r -- "$action" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  case "$plain_action" in
    "󰒓 Show recent logs (last 50 lines)")
      journalctl -u "$service" -n 50 --no-pager
      ;;
    "󰐊 Follow logs (live)")
      echo "Press Ctrl+C to exit live logs."
      journalctl -u "$service" -f
      ;;
    "󰒓 Show logs since today")
      journalctl -u "$service" --since today --no-pager
      ;;
    "󰒓 Show full logs")
      journalctl -u "$service" --no-pager
      ;;
    "󰅙 Quit"|*)
      echo "🚪 Exiting."
      ;;
  esac
}
