#!/bin/zsh

exp.() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  typeset -A commands=(
    ["󰄬 Check text_expander Status"]="systemctl status text_expander --no-pager"
    ["󰐊 Start text_expander"]="sudo systemctl start text_expander"
    ["󰓛 Stop text_expander"]="sudo systemctl stop text_expander"
    ["󰑓 Restart text_expander"]="sudo systemctl restart text_expander"
    ["󰒓 View Logs"]="journalctl -u text_expander --no-pager -n 100"
    ["󰒓 List Triggers"]="/usr/local/bin/text_expander --list-triggers"
    ["󰏫 Edit Base Config (nvim)"]="nvim ~/.config/text_expander/base.yml"
    ["󰏫 Edit Matches"]="edit_match"
    ["󰐕 Add New Trigger"]="add_trigger"
    ["󰅙 Quit"]="return"
  )

  local -a menu=(
    "${cyan}󰄬${reset} ${purple}Check text_expander Status${reset}"
    "${green}󰐊${reset} ${purple}Start text_expander${reset}"
    "${red}󰓛${reset} ${purple}Stop text_expander${reset}"
    "${yellow}󰑓${reset} ${purple}Restart text_expander${reset}"
    "${cyan}󰒓${reset} ${purple}View Logs${reset}"
    "${cyan}󰒓${reset} ${purple}List Triggers${reset}"
    "${yellow}󰏫${reset} ${purple}Edit Base Config (nvim)${reset}"
    "${yellow}󰏫${reset} ${purple}Edit Matches${reset}"
    "${green}󰐕${reset} ${purple}Add New Trigger${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height=12 --prompt="text_expander › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  if [[ -n $plain_choice ]]; then
    eval "${commands[$plain_choice]}"
  fi
}

add_trigger() {
  local match_dir="$HOME/.config/text_expander"
  local target=$(find "$match_dir" -maxdepth 1 -type f -name '*.yml' | fzf --no-preview --prompt="Select target YAML: " --height=10)
  local tmpfile=$(mktemp)

  if [[ -z "$target" ]]; then
    return 1
  fi

  echo "Selected file: $target"
  echo "You can add multiple triggers. Press ENTER on an empty trigger to finish."
  echo

  while true; do
    echo -n "Enter Trigger (e.g ;sea) or ENTER to Exit: "
    read trigger
    [[ -z "$trigger" ]] && break

    echo -n "Enter Replacement: "
    read replace

    if [[ -z "$replace" ]]; then
      echo "Replace text cannot be empty."
      continue
    fi

    echo "  - trigger: \"$trigger\"" >> "$tmpfile"
    echo "    replace: \"$replace\"" >> "$tmpfile"
    echo "Buffered trigger \"$trigger\""
  done

  if [[ -s "$tmpfile" ]]; then
    echo >> "$target"
    cat "$tmpfile" >> "$target"
    echo "All triggers appended to $target"
    echo "Run 'sudo systemctl restart text_expander' when ready."
  else
    echo "No triggers were added."
  fi

  rm -f "$tmpfile"
}

edit_match() {
  local match_dir="$HOME/.config/text_expander"
  local target=$(find "$match_dir" -maxdepth 1 -type f -name '*.yml' | fzf --no-preview --prompt="Select YAML to edit: " --height=10)

  if [[ -z "$target" ]]; then
    return 1
  fi

  nvim "$target"
}
