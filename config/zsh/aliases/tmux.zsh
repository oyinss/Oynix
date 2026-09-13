#!/bin/zsh

# tmx — fzf-driven tmux session manager, styled after the `pis` menu function.
#
# Usage:
#   tmx                        interactive menu
#   tmx ls                     list sessions (table)
#   tmx new [name] [dir]       create a session (attach outside tmux / switch inside)
#   tmx attach [name]          attach outside tmux, switch-client inside tmux
#   tmx rename [old] [new]     rename a session
#   tmx kill [name]            kill a session, with a live-work check
#   tmx repo                   new session for a git repo under $TMUX_REPO_ROOT
#
# Context matters: `tmux new`/`attach` start a client, which cannot nest, so
# inside a session these helpers use attach-avoiding verbs (switch-client).

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# Read-only: one line per session, "name<TAB>windows<TAB>attached|detached".
_tm_session_rows() {
  emulate -L zsh
  command tmux list-sessions \
    -F $'#{session_name}\t#{session_windows}\t#{?session_attached,attached,detached}' 2>/dev/null
}

# Exact-name session lookup ("=name" forces a name match, not an id match).
_tm_session_exists() {
  emulate -L zsh
  command tmux has-session -t "=$1" 2>/dev/null
}

# Foreground work inside a session's panes. Empty = every pane sits at a shell.
# Uses pane_current_command (the pane's foreground process) rather than shell
# children: a session created with an explicit command runs that command as the
# pane process itself, and a shell's transient children (e.g. the figlet|lolcat
# startup banner) would otherwise read as "work".
_tm_session_work() {
  emulate -L zsh
  local name="$1" entry pid cmd
  local -a panes
  panes=(${(f)"$(command tmux list-panes -t "=$name" \
    -F '#{pane_pid}|#{pane_current_command}' 2>/dev/null)"})
  for entry in "${panes[@]}"; do
    pid=${entry%%|*}
    cmd=${entry#*|}
    case "$cmd" in
      zsh|bash|sh|dash|ksh|mksh|fish|tmux) ;;   # bare shell = idle
      *) print -r -- "pid=$pid  cmd=$cmd" ;;
    esac
  done
}

_tm_current_session() {
  emulate -L zsh
  [[ -n "$TMUX" ]] || return 1
  command tmux display-message -p '#{session_name}' 2>/dev/null
}

# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------

_tm_list_sessions() {
  emulate -L zsh
  local reset=$'\033[0m' purple=$'\033[38;5;141m' cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m' yellow=$'\033[38;5;221m'

  local -a sessions
  sessions=(${(f)"$(_tm_session_rows)"})
  if (( ${#sessions[@]} == 0 )); then
    echo "No tmux sessions running."
    return 0
  fi

  local line name rest windows state
  local current=""
  current=$(_tm_current_session) 2>/dev/null

  local name_w=7                       # "Session"
  for line in "${sessions[@]}"; do
    name=${line%%$'\t'*}
    (( ${#name} > name_w )) && name_w=${#name}
  done

  printf '%-*s  %-7s  %s\n' "$name_w" "Session" "Windows" "Status"
  local sep; printf -v sep '%*s' $(( name_w + 2 + 7 + 2 + 8 )) ''; sep=${sep// /─}
  printf '%s\n' "$sep"

  for line in "${sessions[@]}"; do
    name=${line%%$'\t'*}
    rest=${line#*$'\t'}
    windows=${rest%%$'\t'*}
    state=${rest#*$'\t'}
    local mark="" color="$reset"
    [[ "$state" == attached ]] && color="$green" || color="$yellow"
    [[ -n "$current" && "$name" == "$current" ]] && mark=" ${purple}← current${reset}"
    printf "%-*s  ${cyan}%-7s${reset}  ${color}%s${reset}%s\n" \
      "$name_w" "$name" "${windows}w" "$state" "$mark"
  done
}

# fzf picker over sessions; echoes the plain session name.
_tm_pick_session() {
  emulate -L zsh
  local reset=$'\033[0m' purple=$'\033[38;5;141m' cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m' yellow=$'\033[38;5;221m'
  local prompt="${1:-Pick a session}"

  local -a sessions
  sessions=(${(f)"$(_tm_session_rows)"})
  if (( ${#sessions[@]} == 0 )); then
    echo "No tmux sessions running." >&2
    return 1
  fi

  local line name rest windows state color
  local -a rows
  for line in "${sessions[@]}"; do
    name=${line%%$'\t'*}
    rest=${line#*$'\t'}
    windows=${rest%%$'\t'*}
    state=${rest#*$'\t'}
    [[ "$state" == attached ]] && color="$green" || color="$yellow"
    rows+=("${purple}󰆍 ${name}${reset}  ${cyan}${windows}w${reset}  ${color}${state}${reset}"$'\t'"$name")
  done

  local selected
  selected=$(printf '%s\n' "${rows[@]}" | fzf --no-preview --ansi --height 20 --layout=reverse \
    --delimiter=$'\t' --with-nth 1 --prompt "${prompt} › " --border) || return 1
  [[ -z "$selected" ]] && return 1
  selected=$(print -r -- "$selected" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')
  print -r -- "${selected##*$'\t'}"
}

_tm_new_session() {
  emulate -L zsh
  local name="$1" dir="$2"

  if [[ -z "$name" ]]; then
    read "name?Session name [${PWD:t}]: "
    name=${name:-${PWD:t}}
  fi
  dir=${dir:-$PWD}
  dir=${~dir}

  if [[ -z "$name" ]]; then
    echo "ERROR: session name is required." >&2
    return 1
  fi
  if [[ ! -d "$dir" ]]; then
    echo "ERROR: directory not found: $dir" >&2
    return 1
  fi

  if [[ -n "$TMUX" ]]; then
    # Inside a session: create detached, then move this client.
    if ! _tm_session_exists "$name"; then
      if ! command tmux new-session -d -s "$name" -c "$dir"; then
        echo "ERROR: failed to create session '$name'." >&2
        return 1
      fi
    fi
    if command tmux switch-client -t "=$name"; then
      echo "OK: switched to '$name'."
    else
      echo "ERROR: '$name' exists but switching failed - attach with: tmux a -t $name" >&2
      return 1
    fi
  else
    # Outside tmux: -A makes it idempotent (attach if present, else create).
    command tmux new -As "$name" -c "$dir" || {
      echo "ERROR: failed to start session '$name'." >&2
      return 1
    }
  fi
}

_tm_attach_session() {
  emulate -L zsh
  local name="$1"
  if ! _tm_session_exists "$name"; then
    echo "ERROR: no such session: $name" >&2
    return 1
  fi
  if [[ -n "$TMUX" ]]; then
    command tmux switch-client -t "=$name"
  else
    command tmux attach -t "=$name"
  fi
}

_tm_kill_session() {
  emulate -L zsh
  local name="$1"

  if [[ -z "$name" ]]; then
    name=$(_tm_pick_session "Kill session") || return 1
  fi
  if ! _tm_session_exists "$name"; then
    echo "ERROR: no such session: $name" >&2
    return 1
  fi

  local work
  work=$(_tm_session_work "$name")
  if [[ -n "$work" ]]; then
    echo "WARN: '$name' still has running processes:"
    print -r -- "$work"
    local reply
    read -k 1 "reply?Kill anyway? [y/N] "
    echo
    [[ "$reply" == [yY] ]] || { echo "Cancelled - nothing killed."; return 1 }
  fi

  if command tmux kill-session -t "=$name"; then
    echo "OK: killed session '$name'."
  else
    echo "ERROR: failed to kill '$name'." >&2
    return 1
  fi
}

# Rename a session. tmux session names may not contain '.' or ':'.
_tm_rename_session() {
  emulate -L zsh
  local old="$1" new="$2"

  if [[ -z "$old" ]]; then
    old=$(_tm_pick_session "Rename session") || return 1
  fi
  if ! _tm_session_exists "$old"; then
    echo "ERROR: no such session: $old" >&2
    return 1
  fi

  if [[ -z "$new" ]]; then
    read "new?New name for '$old': "
  fi
  new=${new//[.:]/}          # tmux forbids '.' and ':' in session names
  new=${new// /-}
  if [[ -z "$new" ]]; then
    echo "ERROR: a new name is required." >&2
    return 1
  fi
  if [[ "$new" == "$old" ]]; then
    echo "OK: '$old' already has that name."
    return 0
  fi
  if _tm_session_exists "$new"; then
    echo "ERROR: a session named '$new' already exists." >&2
    return 1
  fi

  if command tmux rename-session -t "=$old" "$new"; then
    echo "OK: renamed '$old' -> '$new'."
  else
    echo "ERROR: failed to rename '$old'." >&2
    return 1
  fi
}

# New session for a git repo found under $TMUX_REPO_ROOT.
_tm_repo_session() {
  emulate -L zsh
  local reset=$'\033[0m' purple=$'\033[38;5;141m' cyan=$'\033[38;5;80m'
  local base="${TMUX_REPO_ROOT:-$HOME/Apex/primordial}"

  if [[ ! -d "$base" ]]; then
    echo "ERROR: repo root not found: $base" >&2
    return 1
  fi

  local -a repos
  repos=(${(f)"$(command find "$base" -maxdepth 2 -type d -name .git -prune 2>/dev/null \
    | sed 's|/\.git$||' | sort)"})
  if (( ${#repos[@]} == 0 )); then
    echo "ERROR: no git repos found under $base" >&2
    return 1
  fi

  local picked dir
  picked=$(printf '%s\n' "${repos[@]}" \
    | sed "s|^${base}/||" \
    | fzf --ansi --height 20 --layout=reverse --prompt "Pick a repo › " \
        --border --preview "git -C ${base}/{} log --oneline -5 2>/dev/null" 2>/dev/null)
  [[ -z "$picked" ]] && return 1

  dir="$base/$picked"
  [[ -d "$dir" ]] || { echo "ERROR: directory not found: $dir" >&2; return 1; }
  echo "${cyan}Repo:${reset} ${purple}${dir}${reset}"
  _tm_new_session "${dir:t}" "$dir"
}

# ---------------------------------------------------------------------------
# menu flow wrappers
# ---------------------------------------------------------------------------

_tm_attach_flow() {
  emulate -L zsh
  local name
  name=$(_tm_pick_session "Attach / switch to session") || return 1
  [[ -n "$name" ]] || return 1
  TMUX_SKIP_PAUSE=1
  _tm_attach_session "$name"
}

_tm_new_flow() {
  emulate -L zsh
  local name dir
  read "name?Session name [${PWD:t}]: "
  name=${name:-${PWD:t}}
  read "dir?Directory [$PWD]: "
  dir=${dir:-$PWD}
  [[ -n "$TMUX" ]] && TMUX_SKIP_PAUSE=1
  _tm_new_session "$name" "$dir"
}

_tm_repo_flow() {
  emulate -L zsh
  [[ -n "$TMUX" ]] && TMUX_SKIP_PAUSE=1
  _tm_repo_session
}

_tm_rename_flow() {
  emulate -L zsh
  local old
  old=$(_tm_pick_session "Rename session") || return 1
  [[ -n "$old" ]] || return 1
  _tm_rename_session "$old"
}

# ---------------------------------------------------------------------------
# entry point
# ---------------------------------------------------------------------------

tmx() {
  emulate -L zsh

  if ! command -v tmux >/dev/null 2>&1; then
    echo "ERROR: tmux not found in PATH." >&2
    return 1
  fi

  case "$1" in
    ls|list)
      _tm_list_sessions
      return $?
      ;;
    new)
      _tm_new_session "$2" "$3"
      return $?
      ;;
    attach|a|switch)
      local target="$2"
      if [[ -z "$target" ]]; then
        target=$(_tm_pick_session "Attach / switch to session") || return 1
      fi
      [[ -n "$target" ]] || return 1
      _tm_attach_session "$target"
      return $?
      ;;
    rename|rn)
      _tm_rename_session "$2" "$3"
      return $?
      ;;
    kill|rm)
      _tm_kill_session "$2"
      return $?
      ;;
    repo)
      _tm_repo_session
      return $?
      ;;
    ""|menu)
      ;;
    *)
      echo "Unknown tmx command: $1" >&2
      echo "Usage: tmx [ls|new|attach|rename|kill|repo]" >&2
      return 1
      ;;
  esac

  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  local attach_label="󰆍 Attach / Switch Session"
  local new_label="󰐕 New Session"
  local repo_label="󰉋 New Session for Repo"
  local rename_label="󰏫 Rename Session"
  local kill_label="󰗼 Kill Session"
  local list_label="󰒓 List Sessions"
  local quit_label="󰅙 Quit"

  declare -A commands=(
    ["$attach_label"]="_tm_attach_flow"
    ["$new_label"]="_tm_new_flow"
    ["$repo_label"]="_tm_repo_flow"
    ["$rename_label"]="_tm_rename_flow"
    ["$kill_label"]="_tm_kill_flow"
    ["$list_label"]="_tm_list_sessions"
    ["$quit_label"]=":"
  )

  local -a menu=(
    "${green}󰆍${reset} ${purple}Attach / Switch Session${reset}"
    "${cyan}󰐕${reset} ${purple}New Session${reset}"
    "${blue}󰉋${reset} ${purple}New Session for Repo${reset}"
    "${yellow}󰏫${reset} ${purple}Rename Session${reset}"
    "${red}󰗼${reset} ${purple}Kill Session${reset}"
    "${yellow}󰒓${reset} ${purple}List Sessions${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  _tm_kill_flow() {
    emulate -L zsh
    local name
    name=$(_tm_pick_session "Kill session") || return 1
    [[ -n "$name" ]] || return 1
    _tm_kill_session "$name"
  }

  local TMUX_DONE=0
  while true; do
    local choice plain_choice
    choice=$(printf '%s\n' "${menu[@]}" | fzf --no-preview --ansi --height 20 \
      --layout=reverse --prompt "TMUX › " --border)
    plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')
    [[ -z "$plain_choice" || "$plain_choice" == "$quit_label" ]] && break

    TMUX_SKIP_PAUSE=0
    "${commands[$plain_choice]}"
    [[ $TMUX_DONE -eq 1 ]] && break
    [[ $TMUX_SKIP_PAUSE -eq 1 ]] && continue
    echo
    local pause=""
    read -k 1 -r "pause?Press Enter to continue or q to quit..."
    echo
    if [[ "$pause" == [qQ] ]]; then
      TMUX_DONE=1
    fi
  done
}
