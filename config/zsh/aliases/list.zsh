#!/bin/zsh

# `ls` the way the fish shell has it (config.fish: `alias ls 'eza --icons=auto'`):
# eza with file-type icons and colours.
#
# eza is resolved ONCE, to an absolute path, and never looked up by name again: a shell
# whose PATH lacks /usr/bin (which is how this config produced "command not found: eza"
# -- note `zz` carries its own /usr/bin/zoxide fallback for the same reason) must not
# error on every cd. If eza cannot be found at all, _ls_eza degrades to plain ls so
# `la`, the `l` picker and the cd hook all keep working.
typeset -g _ls_eza_bin=''
if (( $+commands[eza] )); then
  _ls_eza_bin=${commands[eza]}
else
  for _c in /usr/bin/eza /usr/local/bin/eza /bin/eza; do
    [[ -x $_c ]] && { _ls_eza_bin=$_c; break }
  done
  unset _c
fi

# The helper is deliberately NOT named `ls`: ohmyzsh's theme-and-appearance.zsh (loaded
# via zap) sets `alias ls='ls --color=auto'`, and zsh resolves aliases when it *parses*
# a block -- so a `ls() { }` inside a conditional fails with "parse error near `()'".
_ls_eza() {
  emulate -L zsh
  # --icons=always rather than fish's `--icons=auto`: auto silently drops the icons in
  # terminals its detection does not recognise, and this branch only ever runs on a tty.
  # Non-tty output (pipes, $(...), redirects) goes to real ls, because eza prints
  # nothing at all when given no path and stdout is a pipe.
  if [[ -n $_ls_eza_bin && -t 1 ]]; then
    "$_ls_eza_bin" --icons=always "$@"
  else
    command ls "$@"
  fi
}

alias ls='_ls_eza'

# `la` — same listing as `ls` but including hidden files (.env, .gitignore, ...).
la() {
  emulate -L zsh
  _ls_eza -a "$@"
}

# On every cd: print where you landed, then list it in the same style (hidden files
# included). Registered on chpwd so it fires on cd/pushd only -- never on shell startup,
# never in scripts, and never when output is redirected (the -t 1 guard covers pipes;
# LS_ON_CD=0 disables the whole hook for one cd or a whole shell).
_ls_on_cd() {
  emulate -L zsh
  [[ -t 1 ]] || return
  [[ ${LS_ON_CD:-1} == 0 ]] && return
  (( $+functions[_ls_eza] )) || return
  # %~ collapses $HOME to ~ ; swap it for %d if you want the absolute path.
  # Colour 75 matches the `blue` used by the menus in this file.
  print -rP -- "%F{75}%B%~%b%f"
  _ls_eza -a
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _ls_on_cd

l() {
  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  # Define an associative array with list commands
  declare -A commands=(
    ["󰉋 All Files (with icons)"]="_ls_eza -a"
    ["󰈙 Row View"]="_ls_eza -h"
    ["󰈙 All Row View"]="_ls_eza -a --sort=name --group-directories-first"
    ["󰏗 One Line"]="_ls_eza -1"
    ["󰒓 Details"]="_ls_eza -lh"
    ["󰒓 All Details"]="_ls_eza -lha --sort=name --group-directories-first"
    ["󰉋 Directories Only"]="_ls_eza -lhD"
  )

  local -a menu=(
    "${cyan}󰉋${reset} ${purple}All Files (with icons)${reset}"
    "${cyan}󰈙${reset} ${purple}Row View${reset}"
    "${cyan}󰈙${reset} ${purple}All Row View${reset}"
    "${blue}󰏗${reset} ${purple}One Line${reset}"
    "${blue}󰒓${reset} ${purple}Details${reset}"
    "${blue}󰒓${reset} ${purple}All Details${reset}"
    "${yellow}󰉋${reset} ${purple}Directories Only${reset}"
  )

  # fzf menu selection
  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height 10 --prompt "View Mode › " --border)
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  # Execute selected command
  if [[ -n "$plain_choice" ]]; then
    eval "${commands[$plain_choice]}"
  fi
}
