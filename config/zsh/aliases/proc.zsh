#!/bin/zsh

# █ █ █████ ███   ███ ███ █████
# ██ █ █   █ █ █  █ █ █ █ █
# █ ██ █████ ███   █ █ ███  ███
# █  █ █   █ █ █  █ █ █ █    █
# █  █ █████ █ █ ███ █ █ █ ███

# lsp - list running apps and kill them interactively via fzf
# Usage:
#   lsp                list windowed apps first, then others; pick to kill
#   lsp <pattern>      filter by pattern
lsp() {
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local red=$'\033[38;5;203m'
  local purple=$'\033[38;5;141m'
  local dim=$'\033[2m'
  local reset=$'\033[0m'

  local query="$*"

  local sel
  sel=$(
    {
      # windowed apps (what you see in the bar)
      if command -v wmctrl &>/dev/null; then
        wmctrl -l -p 2>/dev/null | awk '{
          pid=$3
          if (pid+0 == 0) next
          cmdline=""
          while ((getline line < "/proc/" pid "/cmdline") > 0) {
            gsub(/\x00/, " ", line)
            cmdline = line
            break
          }
          close("/proc/" pid "/cmdline")
          n = split(cmdline, a, "/")
          bin = a[n]
          title=""
          for (i=5; i<=NF; i++) title = title " " $i
          gsub(/^ +/, "", title)
          if (length(title) > 50) title = substr(title, 1, 50) "..."
          printf "%s\t  %s\t%s\n", pid, bin, title
        }' 2>/dev/null
      fi

      # non-windowed processes (skip kernel threads, dedup only by PID)
      ps -eo pid,comm,%cpu,%mem --sort=-%mem 2>/dev/null \
        | awk '{
          if ($2 ~ /^\[/) next
          if ($1+0 == 0) next
          # Keep separate instances such as multiple Codex app servers visible.
          if (seen[$1]++) next
          printf "%s\t  %s\t%s cpu  %s mem\n", $1, $2, $3, $4
        }'
    } | command fzf \
        --ansi \
        --multi \
        --header "  TAB select    ENTER kill    ESC cancel" \
        --prompt " > ${query:-} " \
        --query "$query" \
        --height=70% \
        --reverse \
        --info=inline \
        --delimiter=$'\t' \
        --with-nth=1,2,3 \
        --preview 'ps -o pid=,ppid=,stat=,etime=,comm= -p {1} 2>/dev/null' \
        --preview-window=right:30%:wrap
  )

  [[ -z "$sel" ]] && return

  local pids=("${(@f)$(print -r -- "${sel}" | awk -F'\t' '{print $1}' | grep -E '^[0-9]+$')}")
  [[ ${#pids} -eq 0 ]] && return

  # collect all descendant pids recursively
  local -a all_pids
  _lsp_children() {
    local p=$1
    local children
    children=$(awk '{for(i=1;i<=NF;i++) print $i}' "/proc/$p/task/$p/children" 2>/dev/null)
    for c in ${children}; do
      all_pids+=($c)
      _lsp_children "$c"
    done
  }

  for pid in "${pids[@]}"; do
    all_pids+=($pid)
    _lsp_children "$pid"
  done

  # dedup, sort leaf-to-root (kill children first)
  local -a unique_pids
  unique_pids=($(print -l -- "${all_pids[@]}" | sort -rn -u))
  [[ ${#unique_pids} -eq 0 ]] && return

  # Some apps (including Codex Desktop) keep a supervisor alive and respawn
  # selected children. Include each selected process group, except this shell's
  # group, so killing a leaf also stops its supervisor without killing Zsh.
  local shell_pgid
  shell_pgid=$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')
  local -a process_groups
  for pid in "${pids[@]}"; do
    local pgid
    pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ "$pgid" =~ '^[0-9]+$' && "$pgid" != "$shell_pgid" && "$pgid" -gt 1 ]]; then
      process_groups+=($pgid)
    fi
  done
  process_groups=($(print -l -- "${process_groups[@]}" | sort -n -u))

  print -r -- ""
  print -r -- "  ${red}  Killing ${#unique_pids} process(es): ${yellow}${(j:, :)pids[1]}${reset}"
  print -r -- ""

  for pgid in "${process_groups[@]}"; do
    /bin/kill -TERM -- "-$pgid" 2>/dev/null
  done
  for pid in "${unique_pids[@]}"; do
    kill -TERM "$pid" 2>/dev/null
  done
  sleep 0.5

  for pgid in "${process_groups[@]}"; do
    /bin/kill -KILL -- "-$pgid" 2>/dev/null
  done
  for pid in "${unique_pids[@]}"; do
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
  done
  sleep 0.2

  # report
  for pid in "${pids[@]}"; do
    local name
    name=$(ps -o comm= -p "$pid" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
      printf "  %b  %b%s%b %b%s%b\n" "$red" "$cyan" "$pid" "$reset" "$dim" "$name" "$reset"
    else
      printf "  %b✓%b %b%s%b %b%s%b\n" "$green" "$reset" "$cyan" "$pid" "$reset" "$dim" "$name" "$reset"
    fi
  done
  printf "\n"
}
