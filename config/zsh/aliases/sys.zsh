#!/bin/zsh

# ███ █ █ ███   ███ █   ███ ███ ███ ███ ███
# █   █ █ █     █ █ █    █  █ █ █   █   █
#  █   █   █    █ █ █    █  █ █  █  ███  █
#   █  █    █   ███ █    █  ███   █ █     █
# ███  █  ███   █ █ ███ ███ █ █ ███ ███ ███

alias rm="rm -r"
alias cp="cp -r"
alias mkdir="mkdir -p"
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias q="exit"
alias cl="clear"
alias sub="subl"
alias rel="exec zsh"
alias logout="qdbus org.kde.KWin /Session org.kde.KWin.Session.quit"
alias bak="$HOME/Oynix/backup.sh"
alias hibernate="systemctl hibernate"
alias suspend="systemctl suspend"
alias suspend-i="sudo /bin/systemctl suspend -i"
alias root="sudo su"
codei() {
  code-insiders "$@"
}
# Shared picker for zz/zzc: list zoxide's known directories in fzf and print the
# chosen absolute path on stdout. Nothing is printed when the picker is
# cancelled, so callers can do `target=$(_zz_pick)` without capturing UI noise.
_zz_pick() {
  local yellow=$'\033[38;5;221m'
  local cyan=$'\033[38;5;80m'
  local purple=$'\033[38;5;141m'
  local reset=$'\033[0m'

  local zoxide_bin="${commands[zoxide]}"
  [[ -z "$zoxide_bin" && -x /usr/bin/zoxide ]] && zoxide_bin=/usr/bin/zoxide
  if [[ -z "$zoxide_bin" ]]; then
    print -u2 -- "zz/zzc: zoxide is installed but is not available in PATH"
    return 127
  fi

  local selection
  selection=$(
    "$zoxide_bin" query -l "$@" 2>/dev/null | while IFS= read -r dir; do
      local name="${dir##*/}"
      printf "${yellow}󰉋${reset}\t${cyan}%s${reset}\t${purple}%s${reset}\n" "$name" "$dir"
    done | command fzf \
      --ansi \
      --height=40% \
      --reverse \
      --prompt="${_ZZ_PROMPT:-dir > }" \
      --delimiter=$'\t' \
      --with-nth=1,2,3 \
      --nth=2
  ) || return 1

  [[ -z "$selection" ]] && return 1

  local target
  target="${selection##*$'\t'}"
  target="${target#${purple}}"
  target="${target%${reset}}"
  [[ -z "$target" ]] && return 1
  print -r -- "$target"
}

# Jump to a directory from zoxide's history.
zz() {
  local target
  target=$(_zz_pick "$@") || return
  cd "$target" 2>/dev/null || print -u2 -- "No such directory: $target"
}

# Same picker, but copy the selected absolute path to the clipboard instead of
# entering it. The path is also printed, so `target=$(zzc)` works for scripting.
zzc() {
  local target
  _ZZ_PROMPT='copy path > ' target=$(_zz_pick "$@") || return

  if command -v wl-copy >/dev/null 2>&1; then
    print -rn -- "$target" | wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    print -rn -- "$target" | xclip -selection clipboard
  else
    print -u2 -- "zzc: no clipboard tool found (need wl-copy or xclip)"
    return 127
  fi

  print -r -- "$target"
  notify-send -a "zzc" "Path copied" "$target" >/dev/null 2>&1 || true
}

nuke() {
  [[ -z "$1" ]] && { echo "Usage: nuke <process>" >&2; return 1 }
  kill -9 $(ps aux | grep "[${1:0:1}]${1:1}" | awk '{print $2}')
}

sys() {
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'
  local reset=$'\033[0m'

  local choice
  choice=$(
    {
      printf "${green}󰠱${reset}\tFiglet Fonts\t\tshowfigfonts\n"
      printf "${yellow}󰋖${reset}\tCleanup /tmp\t\tfind /tmp -maxdepth 1 -user \"\$USER\" -name '*.so' -type f -mtime +1 -delete && df -h /tmp\n"
      printf "${cyan}󰑭${reset}\tSwitch User\t\tsudo -i -u\n"
      printf "${cyan}󰒋${reset}\tView Swappiness\t\tbat /proc/sys/vm/swappiness\n"
      printf "${green}󰒊${reset}\tSet Swappiness 10\t\tsudo tee /etc/sysctl.conf <<< \"vm.swappiness=10\"\n"
      printf "${yellow}󰍽${reset}\tTrackpad: Disable\t\thyprctl eval 'hl.device({ name = \"cust0001:00-06cb:cdaa-touchpad\", enabled = false })'\n"
      printf "${yellow}󰍽${reset}\tTrackpad: Enable\t\thyprctl eval 'hl.device({ name = \"cust0001:00-06cb:cdaa-touchpad\", enabled = true })'\n"
      printf "${blue}󰉋${reset}\tFile: List Row\t\teza -h --icons=auto\n"
      printf "${blue}󰉋${reset}\tFile: List All Row\t\teza -a --icons=auto --sort=name --group-directories-first\n"
      printf "${blue}󰉋${reset}\tFile: List\t\teza -1 --icons=auto\n"
      printf "${blue}󰉋${reset}\tFile: List All\t\teza -a --icons=auto --sort=name --group-directories-first -1\n"
      printf "${blue}󰉋${reset}\tFile: List Details\t\teza -lh --icons=auto\n"
      printf "${blue}󰉋${reset}\tFile: List All Details\t\teza -lha --icons=auto --sort=name --group-directories-first\n"
      printf "${blue}󰉋${reset}\tFile: List Dir Only\t\teza -lhD --icons=auto\n"
      printf "${yellow}󰅪${reset}\tFind PID\t\tps aux | grep -i\n"
      printf "${red}󰅪${reset}\tKill PID\t\tkill -9\n"
      printf "${red}󰜭${reset}\tNuke Process\t\tnuke\n"
      printf "${green}󰍉${reset}\tFZF Find\t\tls -a | fzf -i\n"
      printf "${green}󰷾${reset}\tGrep Find\t\tls -a | grep -Ei\n"
      printf "${green}󰈔${reset}\tFind by Name\t\tfind . -iname\n"
      printf "${orange}󰏗${reset}\tNPM Global List\t\tnpm list -g --depth=0\n"
      printf "${orange}󰏗${reset}\tNPM Global Owner\t\tls -la \"\$(npm root -g)\"\n"
      printf "${orange}󰏗${reset}\tNPM Global Chown\t\tsudo chown -R \"\$USER\" \"\$(npm root -g)\"\n"
      printf "${green}󰁯${reset}\tBackup Dotfiles\t\tbash \"\$HOME/Oynix/backup.sh\"\n"
      printf "${yellow}󰋊${reset}\tDisk Free\t\tdf -h\n"
      printf "${yellow}󰋊${reset}\tFolder Size\t\tdu -sh\n"
      printf "${green}󰓅${reset}\tFree Memory\t\tfree -m\n"
      printf "${red}󰐊${reset}\tQuit\n"
    } | command fzf \
      --ansi \
      --height=40% \
      --reverse \
      --prompt "sys > " \
      --delimiter=$'\t' \
      --with-nth=1,2 \
      --nth=2
  )

  [[ -z "$choice" ]] && return

  local cmd
  cmd="${choice##*$'\t'}"
  [[ -z "$cmd" || "$cmd" == "Quit" ]] && return

  case "$cmd" in
    nuke)
      local proc
      echo -n "Process to kill: "
      read -r proc
      [[ -n "$proc" ]] && nuke "$proc"
      ;;
    *)
      eval "$cmd"
      ;;
  esac
}
