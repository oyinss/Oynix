# ----------------------------
# QUICK COMMANDS (TOP LEVEL)
# ----------------------------

# Install a package (quick)
alias deploy="paru -S"

# Remove a package (quick)
alias purge="paru -R"


# ----------------------------
# INTERACTIVE UPDATE MENU
# ----------------------------

arch() {
  local choice
  local plain_choice
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  local sync_label="󰑓 Update databases only (paru -Sy)"
  local upgrade_label="󰚰 Full system upgrade (paru -Syu)"
  local install_label="󰏖 Install / upgrade a package"
  local remove_label="󰆴 Remove package + unneeded deps (paru -Rs)"
  local remove_all_label="󰚌 Remove package + all deps (paru -Rns)"
  local local_file_label="󰈙 Install local package file (paru -U)"
  local search_label="󰍉 Search packages (paru -Ss)"
  local query_label="󰋼 Query installed packages (paru -Qs)"
  local installed_label="󰄬 Check if package is installed"
  local provides_label="󰌷 Find package providing a file (paru -F)"
  local orphans_label="󰆴 Remove orphan packages"
  local downgrade_label="󰑕 Downgrade packages (paru -Suu)"
  local clean_label="󰃢 Clean package cache (paru -Sc)"
  local clean_all_label="󰜉 Clean ALL cache (paru -Scc)"
  local unlock_label="󰌾 Unlock pacman database"
  local quit_label="󰅙 Quit"

  choice=$(printf "%s\n" \
    "${green}󰚰${reset} ${purple}Full system upgrade (paru -Syu)${reset}" \
    "${yellow}󰑓${reset} ${purple}Update databases only (paru -Sy)${reset}" \
    "${green}󰏖${reset} ${purple}Install / upgrade a package${reset}" \
    "${red}󰆴${reset} ${purple}Remove package + unneeded deps (paru -Rs)${reset}" \
    "${red}󰚌${reset} ${purple}Remove package + all deps (paru -Rns)${reset}" \
    "${cyan}󰈙${reset} ${purple}Install local package file (paru -U)${reset}" \
    "${cyan}󰍉${reset} ${purple}Search packages (paru -Ss)${reset}" \
    "${blue}󰋼${reset} ${purple}Query installed packages (paru -Qs)${reset}" \
    "${cyan}󰄬${reset} ${purple}Check if package is installed${reset}" \
    "${orange}󰌷${reset} ${purple}Find package providing a file (paru -F)${reset}" \
    "${red}󰆴${reset} ${purple}Remove orphan packages${reset}" \
    "${yellow}󰑕${reset} ${purple}Downgrade packages (paru -Suu)${reset}" \
    "${yellow}󰃢${reset} ${purple}Clean package cache (paru -Sc)${reset}" \
    "${orange}󰜉${reset} ${purple}Clean ALL cache (paru -Scc)${reset}" \
    "${orange}󰌾${reset} ${purple}Unlock pacman database${reset}" \
    "${red}󰅙${reset} ${purple}Quit${reset}" \
    | command fzf --no-preview --ansi --height 18 --prompt "Arch › " --border)

  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  case "$plain_choice" in
    "$sync_label")
      paru -Sy
      ;;
    "$upgrade_label")
      paru -Syu
      ;;
    "$install_label")
      read "?Enter package name: " pkg
      [[ -n "$pkg" ]] && paru -S "$pkg"
      ;;
    "$remove_label")
      read "?Enter package name: " pkg
      [[ -n "$pkg" ]] && paru -Rs "$pkg"
      ;;
    "$remove_all_label")
      read "?Enter package name: " pkg
      [[ -n "$pkg" ]] && paru -Rns "$pkg"
      ;;
    "$local_file_label")
      read "?Enter path to package file: " file
      [[ -n "$file" ]] && paru -U "$file"
      ;;
    "$search_label")
      read "?Search term: " term
      [[ -n "$term" ]] && paru -Ss "$term"
      ;;
    "$query_label")
      read "?Query term: " term
      [[ -n "$term" ]] && paru -Qs "$term"
      ;;
    "$installed_label")
      read "?Package name: " term
      [[ -n "$term" ]] && paru -Q | grep "$term"
      ;;
    "$provides_label")
      read "?File name or path: " term
      [[ -n "$term" ]] && paru -F "$term"
      ;;
    "$orphans_label")
      orphans=$(paru -Qtdq)
      [[ -n "$orphans" ]] && paru -R $orphans || echo "No orphan packages found"
      ;;
    "$downgrade_label")
      paru -Suu
      ;;
    "$clean_label")
      paru -Sc
      ;;
    "$clean_all_label")
      paru -Scc
      ;;
    "$unlock_label")
      sudo rm -rf /var/lib/pacman/db.lck
      ;;
    *)
      return
      ;;
  esac
}
