#!/bin/zsh

ts() {
  local orange=$'\033[38;5;208m'
  local red=$'\033[38;5;203m'
  local purple=$'\033[38;5;141m'
  local reset=$'\033[0m'

  local choice
  choice=$(
    {
      printf "${orange}󰑓${reset}\tTimeshift Backup\t\tsudo timeshift --create --comments\n"
      printf "${red}󰑓${reset}\tTimeshift Restore\t\tsudo timeshift --restore\n"
    } | command fzf \
      --ansi \
      --height=20% \
      --reverse \
      --prompt "ts > " \
      --delimiter=$'\t' \
      --with-nth=2 \
      --nth=2
  )

  [[ -z "$choice" ]] && return

  local cmd
  cmd="${choice##*$'\t'}"
  [[ -z "$cmd" ]] && return

  eval "$cmd"
}
