#!/bin/zsh

# --------------------------------------------------------
# Systemctl Services and Control
# --------------------------------------------------------
alias ctlprocess="sudo systemctl --failed"
alias ctlservices="systemctl list-unit-files --type=service"
alias ctllist="systemctl list-unit-files --type=service"
alias ctlreload="sudo systemctl daemon-reload"
alias ctlenable="sudo systemctl enable"
alias ctlstart="sudo systemctl start"
alias ctlrestart="sudo systemctl restart"
alias ctlstatus="sudo systemctl status"

ctl() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  echo "Reloading systemd daemon..."
  sudo systemctl daemon-reload

  local service=$(systemctl list-units --type=service --all --no-pager --no-legend \
    | awk '{print $1}' | fzf --no-preview --prompt="Select service: " --height=15)

  if [[ -z "$service" ]]; then
    return 1
  fi

  echo "Selected: $service"

  local -a menu=(
    "${green}󰄬${reset} ${purple}Enable now${reset}"
    "${red}󰅖${reset} ${purple}Disable now${reset}"
    "${green}󰐊${reset} ${purple}Start${reset}"
    "${yellow}󰑓${reset} ${purple}Restart${reset}"
    "${cyan}󰒓${reset} ${purple}Status${reset}"
    "${orange}󰅙${reset} ${purple}Cancel${reset}"
  )

  local action plain_action
  action=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --prompt="Action › " --height=7)
  plain_action=$(print -r -- "$action" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  case "$plain_action" in
    "󰄬 Enable now")
      sudo systemctl enable "$service"
      echo "Enabled $service"
      ;;
    "󰅖 Disable now")
      sudo systemctl disable "$service"
      echo "Disabled $service"
      ;;
    "󰐊 Start")
      sudo systemctl start "$service"
      echo "Started $service"
      ;;
    "󰑓 Restart")
      sudo systemctl restart "$service"
      echo "Restarted $service"
      ;;
    "󰒓 Status")
      systemctl status "$service"
      ;;
    "󰅙 Cancel")
      echo "Cancelled."
      ;;
    *)
      return
      ;;
  esac
}
