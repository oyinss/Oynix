#!/bin/zsh

# ███ █ █ ███ █ █ ███ █   █   ███ █   ███ ███ ███ ███ ███
# █ █ █ █  █  █ █ █ █ ██  █   █ █ █    █  █ █ █   █   █
# ███  █   █  ███ █ █ █ █ █   █ █ █    █  █ █  █  ███  █
# █    █   █  █ █ █ █ █  ██   ███ █    █  ███   █ █     █
# █    █   █  █ █ ███ █   █   █ █ ███ ███ █ █ ███ ███ ███

# -------------------------------------------
# Activate or create environment variable for python in current directory if not available
# -------------------------------------------
myenv() {
    venv_name="myenv"

    if [ -d "$venv_name" ]; then
        source "$venv_name/bin/activate"
    else
        python -m venv "$venv_name"
        source "$venv_name/bin/activate"
    fi
}

m.py() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with Python-related commands as keys and corresponding commands as values
  declare -A commands=(
    ["󰐊 Run Python App"]="python app.py"
    ["󰆍 Run Python Test"]="python test.py"
    ["󰖟 Run Flask App on Port 8000"]="flask run --port=8000"
    ["󰋼 Python Version"]="python --version"
    ["󰒓 Pip3 List"]="pip3 list"
    ["󰇚 Pip3 Install"]="pip3 install"
    ["󰆴 Pip3 Uninstall"]="pip3 install"
    # ["Deactivate myenv"]="deactivate"
    ["󰚰 Upgrade Packages (Pip3)"]="pip3 install --upgrade"
    ["󰑓 Switch Python Version"]="sudo update-alternatives --config python3"
    ["󰅙 Quit"]=": # Do nothing"
  )

  local -a menu=(
    "${green}󰐊${reset} ${purple}Run Python App${reset}"
    "${cyan}󰆍${reset} ${purple}Run Python Test${reset}"
    "${blue}󰖟${reset} ${purple}Run Flask App on Port 8000${reset}"
    "${cyan}󰋼${reset} ${purple}Python Version${reset}"
    "${cyan}󰒓${reset} ${purple}Pip3 List${reset}"
    "${green}󰇚${reset} ${purple}Pip3 Install${reset}"
    "${red}󰆴${reset} ${purple}Pip3 Uninstall${reset}"
    "${yellow}󰚰${reset} ${purple}Upgrade Packages (Pip3)${reset}"
    "${yellow}󰑓${reset} ${purple}Switch Python Version${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  # Use fzf to display the options and store the selection
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 10 --prompt "Select a Python command: " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the corresponding command based on the selection
  if [[ -n $plain_choice ]]; then
    eval "${commands[$plain_choice]}"
  fi
}

# # Run python
py() {
    local file
    file=$( (echo "main.py"; find . -type f -name "*.py" ! -path "./myenv/*" ! -path "./__pycache__/*" ! -name "main.py" | sed 's|^\./||') | fzf --preview "bat --style=numbers --color=always --line-range :500 {}" --height 40% --border --ansi)
    if [[ -n "$file" ]]; then
        python "$file"
    fi
}
