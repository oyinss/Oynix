#!/bin/zsh

# █   █ ███ ███ ███ ███ ███   ███ █   ███ ███ ███ ███ ███
# ██ ██  █  █ █ █ █ █ █ █ █   █ █ █    █  █ █ █   █   █
# █ █ █  █  ██  ██  █ █ ██    █ █ █    █  █ █  █  ███  █
# █   █  █  █ █ █ █ █ █ █ █   ███ █    █  ███   █ █     █
# █   █ ███ █ █ █ █ ███ █ █   █ █ ███ ███ █ █ ███ ███ ███

_mirror_refresh() (
  emulate -L zsh
  setopt pipefail
  local mode=${1:-quick} preview=${2:-} candidates=12 keep=5 budget=40
  if [[ $mode == thorough ]]; then
    candidates=40 keep=10 budget=120
  fi
  if [[ -n $preview && $preview != --preview ]]; then
    print -u2 -- 'Usage: mirror {quick|thorough} [--preview]'
    return 2
  fi
  local tool
  for tool in reflector rate-mirrors timeout mktemp; do
    if (( ! $+commands[$tool] )); then
      print -u2 -- "Required command not found: $tool"
      return 1
    fi
  done
  local workdir
  workdir=$(mktemp -d) || return 1
  trap 'rm -rf -- "$workdir"' EXIT
  local started=$SECONDS
  print -- "Testing up to $candidates fresh HTTPS mirrors (${budget}s limit)…"
  if ! timeout -k 2s 10s reflector \
      --protocol https --age 12 --latest "$candidates" \
      --sort score --connection-timeout 3 \
      --save "$workdir/candidates"; then
    print -u2 -- 'Could not fetch fresh mirrors; your current list was not changed.'
    return 1
  fi
  local remaining=$(( budget - (SECONDS - started) ))
  if (( remaining <= 0 )); then
    print -u2 -- 'Mirror search timed out; your current list was not changed.'
    return 1
  fi
  # Short streaming samples avoid downloading the entire database per mirror.
  # The fallback flag prevents installing untested servers if every test fails.
  if ! sed -n 's|^Server = \(.*\)/\$repo/os/\$arch$|\1/|p' "$workdir/candidates" |
      timeout -k 2s "${remaining}s" rate-mirrors \
        --protocol https --concurrency 3 --concurrency-for-unlabeled 3 \
        --per-mirror-timeout 3000 --min-per-mirror 200 --max-per-mirror 600 \
        --min-bytes-per-mirror 32768 --max-mirrors-to-output "$keep" \
        --disable-untested-fallback --save "$workdir/mirrorlist" \
        stdin --path-to-test extra/os/x86_64/extra.db \
        --path-to-return '$repo/os/$arch' --output-prefix 'Server = ' \
        >"$workdir/rating.log" 2>&1; then
    cat -- "$workdir/rating.log" >&2
    print -u2 -- 'Mirror ranking failed or timed out; your current list was not changed.'
    return 1
  fi
  if ! command grep -q '^Server = https://' "$workdir/mirrorlist"; then
    print -u2 -- 'No usable mirrors measured; your current list was not changed.'
    return 1
  fi
  print -- "Ranking finished in $(( SECONDS - started )) seconds."
  if [[ $preview == --preview ]]; then
    cat -- "$workdir/mirrorlist"
    return
  fi
  # These commands run in the user's terminal, where sudo can prompt normally.
  sudo cp -- /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup || return 1
  sudo install -m 644 -- "$workdir/mirrorlist" /etc/pacman.d/mirrorlist || return 1
  print -- 'Updated Arch mirrors. Previous list: /etc/pacman.d/mirrorlist.backup'
)

mirror() {
  case ${1:-} in
    quick|thorough) _mirror_refresh "$@"; return $? ;;
    '') ;;
    *) print -u2 -- 'Usage: mirror [quick|thorough] [--preview]'; return 2 ;;
  esac
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with mirror commands
  local -A mirror_actions=(
    ["󰖟 Quick Arch Mirrors (test 12, keep 5)"]="_mirror_refresh quick"
    ["󰖟 Broader Arch Search (test 40, keep 10)"]="_mirror_refresh thorough"
    ["󰚰 Rate Update Manjaro Mirrors"]="rate-mirrors --allow-root --protocol https manjaro | sudo tee /etc/pacman.d/mirrorlist"
    ["󰚰 Rate Update EndeavourOS Mirrors"]="rate-mirrors --allow-root --protocol https endeavouros | sudo tee /etc/pacman.d/endeavouros-mirrorlist"
    ["󰒓 Rank Current Mirrors"]="rankmirrors /etc/pacman.d/mirrorlist"
    ["󰈙 EndeavourOS Mirror List"]="sudo nvim /etc/pacman.d/endeavouros-mirrorlist"
    ["󰈙 Arch Mirror List"]="sudo nvim /etc/pacman.d/mirrorlist"
    ["󰈙 Chaotic Mirror List"]="sudo nvim /etc/pacman.d/chaotic-mirrorlist"
    ["󰏫 Configure pacman.conf"]="sudo nvim /etc/pacman.conf"
    ["󰅙 Quit"]=": # Do nothing"
  )

  local -a menu=(
    "${blue}󰖟${reset} ${purple}Quick Arch Mirrors (test 12, keep 5)${reset}"
    "${blue}󰖟${reset} ${purple}Broader Arch Search (test 40, keep 10)${reset}"
    "${green}󰚰${reset} ${purple}Rate Update Manjaro Mirrors${reset}"
    "${green}󰚰${reset} ${purple}Rate Update EndeavourOS Mirrors${reset}"
    "${cyan}󰒓${reset} ${purple}Rank Current Mirrors${reset}"
    "${yellow}󰈙${reset} ${purple}EndeavourOS Mirror List${reset}"
    "${yellow}󰈙${reset} ${purple}Arch Mirror List${reset}"
    "${yellow}󰈙${reset} ${purple}Chaotic Mirror List${reset}"
    "${yellow}󰏫${reset} ${purple}Configure pacman.conf${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  # fzf menu selection
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 15 --prompt "Mirrors › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute the selected command
  if [[ -n $plain_choice ]]; then
    eval "${mirror_actions[$plain_choice]}"
  fi
}
