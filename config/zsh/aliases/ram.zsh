#!/bin/zsh

# ram — print per-application RAM usage in a table like Windows Task Manager.
# Groups all processes of an app (browser tabs, renderers, etc.) into one row
# and sorts by total memory, descending. Usage: ram [N|all]  (default: top 10)

# Map a lowercase process command line to its friendly application name.
# Order matters: more specific matches must come before generic ones.
_ram_classify() {
  local args="${1:l}"    # lowercase for case-insensitive matching

  # Hermes backends (python server processes) — must precede generic "hermes"
  if [[ "$args" == *"hermes_cli"* ]]; then
    print -r -- "Hermes backends"; return
  fi
  if [[ "$args" == *"firefox-developer-edition"* ]]; then
    print -r -- "Firefox Developer Edition"; return
  fi
  if [[ "$args" == *"/firefox/"* ]]; then
    print -r -- "Firefox stable"; return
  fi
  if [[ "$args" == *"discord"* ]]; then
    print -r -- "Discord"; return
  fi
  # Hermes Desktop (electron) — app binary path or matching --user-data-dir
  if [[ "$args" == *"apps/desktop"*hermes* || "$args" == *"user-data-dir"*"/hermes"* ]]; then
    print -r -- "Hermes Desktop"; return
  fi
  if [[ "$args" == *"opencode"* || "$args" == *"ai.opencode.desktop"* ]]; then
    print -r -- "OpenCode Desktop"; return
  fi
  if [[ "$args" == *"codex-desktop"* ]]; then
    print -r -- "Codex Desktop"; return
  fi
  if [[ "$args" == "qs -c ii"* || "$args" == *"quickshell"* ]]; then
    print -r -- "Quickshell"; return
  fi
  if [[ "$args" == *"syncthing"* ]]; then
    print -r -- "Syncthing"; return
  fi
  if [[ "$args" == *"codex-router"* || "$args" == *"litellm"* ]]; then
    print -r -- "Codex Router"; return
  fi
  if [[ "$args" == *"enpass"* ]]; then
    print -r -- "Enpass"; return
  fi
  if [[ "$args" == *"kdeconnectd"* ]]; then
    print -r -- "KDE Connect"; return
  fi
  if [[ "$args" == *"/hyprland"* ]]; then
    print -r -- "Hyprland"; return
  fi
  if [[ "$args" == *"keyd"* ]]; then
    print -r -- "keyd"; return
  fi
  if [[ "$args" == *"node"* || "$args" == *"npm"* ]]; then
    print -r -- "Node.js"; return
  fi
  if [[ "$args" == *"php"* ]]; then
    print -r -- "PHP"; return
  fi
  if [[ "$args" == *"python"* ]]; then
    print -r -- "Python"; return
  fi
  if [[ "$args" == *"Xorg"* ]]; then
    print -r -- "Xorg"; return
  fi

  # Fallback: friendly executable basename (strip leading brackets/slashes).
  local exe="${args[(w)1]}"
  exe="${exe:t}"
  if [[ -z "$exe" || "$exe" == "exe" ]]; then
    # Usually an electron child without an obvious binary — try --user-data-dir
    if [[ "$args" == *"--user-data-dir="* ]]; then
      exe="${args#*--user-data-dir=}"
      exe="${exe%% *}"
      exe="${exe:h:t}"
    else
      exe="Other"
    fi
  fi
  print -r -- "$exe"
}

# 925 MB -> 925 MB ; 2.2 GB etc.
_ram_fmt() {
  local rss="$1"            # KiB
  local mib=$(( rss / 1024 ))
  if (( mib >= 1024 )); then
    local tenths=$(( mib * 10 / 1024 ))
    local whole=$(( tenths / 10 ))
    local tenth=$(( tenths % 10 ))
    if (( tenth == 0 )); then
      print -r -- "${whole} GB"
    else
      print -r -- "${whole}.${tenth} GB"
    fi
  else
    print -r -- "${mib} MB"
  fi
}

ram() {
  emulate -L zsh

  local -A mem=()          # app -> total KiB
  local rss args name

  while read -r rss args; do
    (( rss > 0 )) || continue
    [[ "$args" == \[* ]] && continue        # kernel threads
    name=$(_ram_classify "$args") || continue
    (( mem[$name] += rss ))
  done < <(ps -eo rss=,args=)

  if (( ${#mem[@]} == 0 )); then
    echo "ram: no processes found."
    return 1
  fi

  local max=${1:-10}
  if [[ "$max" == "all" ]]; then
    max=${#mem[@]}
  elif [[ "$max" != <-> ]]; then
    echo "Usage: ram [N|all]   (default N=10)" >&2
    return 1
  fi

  # Build "KiB<TAB>name" lines and sort descending by memory.
  local -a lines=()
  for name in ${(k)mem}; do
    lines+=("${mem[$name]}"$'\t'"$name")
  done
  local -a sorted=(${(f)"$(printf '%s\n' "${lines[@]}" | sort -t $'\t' -k1,1rn)"})

  # Compute value strings and alignment widths.
  local -a disp_names disp_vals
  local line kib val
  local name_w=11            # width of "Application"
  local val_w=11             # width of "Approx. RAM"
  local count=0
  for line in "${sorted[@]}"; do
    (( count >= max )) && break
    kib=${line%%$'\t'*}
    name=${line#*$'\t'}
    val=$(_ram_fmt "$kib")
    disp_names+=("$name")
    disp_vals+=("$val")
    (( ${#name} > name_w )) && name_w=${#name}
    (( ${#val} > val_w )) && val_w=${#val}
    count=$((count + 1))
  done

  # Header + divider (─), then rows.
  printf '%-*s  %*s\n' "$name_w" "Application" "$val_w" "Approx. RAM"
  local divider
  divider=$(printf '─%.0s' {1..$(( name_w + val_w + 2 ))})
  printf '%s\n' "$divider"

  local i
  local total_kib=0
  for (( i=1; i <= ${#disp_names[@]}; i++ )); do
    printf '%-*s  %*s\n' "$name_w" "${disp_names[$i]}" "$val_w" "${disp_vals[$i]}"
  done

  printf '%s\n' "$divider"
  local total_kib=0
  for name in ${(k)mem}; do
    (( total_kib += mem[$name] ))
  done
  printf '%-*s  %*s\n' "$name_w" "Total" "$val_w" "$(_ram_fmt "$total_kib")"
}
